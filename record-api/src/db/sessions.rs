use crate::error::AppError;
use crate::models::{SessionStats, SessionSummary, TrackPoint};

use super::{haversine_km, Database};

impl Database {
    /// 获取所有会话摘要（含距离计算）。
    /// 分两步：先在锁内查询摘要，再在锁外逐会话计算距离，避免嵌套加锁死锁。
    pub fn get_sessions(&self) -> Result<Vec<SessionSummary>, AppError> {
        let sessions = {
            let conn = self.lock()?;
            let mut stmt = conn.prepare(
                "SELECT session_id, MIN(timestamp) as start_time, MAX(timestamp) as end_time,
                        COUNT(*) as point_count, COALESCE(SUM(steps), 0) as total_steps
                 FROM track_points
                 GROUP BY session_id
                 ORDER BY start_time DESC",
            )?;
            let result: Vec<SessionSummary> = stmt
                .query_map([], |row| {
                    Ok(SessionSummary {
                        session_id: row.get(0)?,
                        start_time: row.get(1)?,
                        end_time: row.get(2)?,
                        point_count: row.get(3)?,
                        total_steps: Some(row.get::<_, i64>(4)?),
                        total_distance_km: None,
                    })
                })?
                .filter_map(|r| r.ok())
                .collect();
            result
        };

        let mut result = Vec::with_capacity(sessions.len());
        for mut s in sessions {
            s.total_distance_km = Some(self.calculate_session_distance(&s.session_id)?);
            result.push(s);
        }
        Ok(result)
    }

    /// 计算单个 session 所有轨迹点连线的总距离（km）
    fn calculate_session_distance(&self, session_id: &str) -> Result<f64, AppError> {
        let points = self.get_session_track_points(session_id)?;
        if points.len() < 2 {
            return Ok(0.0);
        }
        let mut total = 0.0;
        for window in points.windows(2) {
            total += haversine_km(
                window[0].latitude,
                window[0].longitude,
                window[1].latitude,
                window[1].longitude,
            );
        }
        Ok(total)
    }

    /// 获取某个会话的所有轨迹点
    pub fn get_session_track_points(&self, session_id: &str) -> Result<Vec<TrackPoint>, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare(
            "SELECT id, session_id, latitude, longitude, altitude, speed, steps, timestamp, created_at
             FROM track_points
             WHERE session_id = ?1
             ORDER BY timestamp ASC",
        )?;

        let points = stmt
            .query_map([session_id], |row| {
                Ok(TrackPoint {
                    id: Some(row.get(0)?),
                    session_id: row.get(1)?,
                    latitude: row.get(2)?,
                    longitude: row.get(3)?,
                    altitude: row.get(4)?,
                    speed: row.get(5)?,
                    steps: row.get(6)?,
                    timestamp: row.get(7)?,
                    created_at: Some(row.get(8)?),
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(points)
    }

    /// 删除一个会话及其所有轨迹点
    pub fn delete_session(&self, session_id: &str) -> Result<usize, AppError> {
        let conn = self.lock()?;
        let deleted = conn.execute(
            "DELETE FROM track_points WHERE session_id = ?1",
            [session_id],
        )?;
        Ok(deleted)
    }

    /// 获取会话实时统计（使用子查询获取最新轨迹点的经纬度）
    pub fn get_session_stats(&self, session_id: &str) -> Result<Option<SessionStats>, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare(
            "SELECT session_id, COUNT(*), COALESCE(SUM(steps), 0),
                    MIN(timestamp),
                    (SELECT latitude FROM track_points WHERE session_id = ?1 ORDER BY timestamp DESC LIMIT 1),
                    (SELECT longitude FROM track_points WHERE session_id = ?1 ORDER BY timestamp DESC LIMIT 1),
                    MAX(timestamp)
             FROM track_points
             WHERE session_id = ?1",
        )?;

        let mut rows = stmt.query_map([session_id], |row| {
            Ok(SessionStats {
                session_id: row.get(0)?,
                point_count: row.get(1)?,
                total_steps: row.get(2)?,
                start_time: row.get(3)?,
                last_latitude: row.get(4)?,
                last_longitude: row.get(5)?,
                last_timestamp: row.get(6)?,
            })
        })?;

        match rows.next() {
            Some(r) => Ok(Some(r?)),
            None => Ok(None),
        }
    }
}
