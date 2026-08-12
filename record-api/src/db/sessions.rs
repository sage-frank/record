use std::collections::HashMap;

use crate::error::AppError;
use crate::models::{SessionStats, SessionSummary, TrackPoint};

use super::{haversine_km, Database};

impl Database {
    /// 获取所有会话摘要（含距离计算）。
    /// 共两次查询：一次聚合摘要 + 一次拉全部轨迹点内存计算距离，
    /// 替代原先"每会话一次查询"的 N+1 模式。
    pub fn get_sessions(&self) -> Result<Vec<SessionSummary>, AppError> {
        let conn = self.pool()?;

        // 第一次查询：会话聚合摘要
        let mut stmt = conn.prepare(
            "SELECT session_id, MIN(timestamp) as start_time, MAX(timestamp) as end_time,
                    COUNT(*) as point_count, COALESCE(SUM(steps), 0) as total_steps
             FROM track_points
             GROUP BY session_id
             ORDER BY MIN(timestamp) DESC",
        )?;
        let mut sessions: Vec<SessionSummary> = stmt
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
            .collect::<rusqlite::Result<Vec<_>>>()?;

        // 第二次查询：全部轨迹点按 (session, 时间) 排序，内存中逐段累加距离
        let mut pts = conn.prepare(
            "SELECT session_id, latitude, longitude
             FROM track_points
             ORDER BY session_id, timestamp ASC",
        )?;
        let mut rows = pts.query([])?;
        let mut distances: HashMap<String, f64> = HashMap::new();
        let mut prev: Option<(String, f64, f64)> = None;
        while let Some(row) = rows.next()? {
            let sid: String = row.get(0)?;
            let lat: f64 = row.get(1)?;
            let lon: f64 = row.get(2)?;
            if let Some((prev_sid, prev_lat, prev_lon)) = &prev {
                if *prev_sid == sid {
                    *distances.entry(sid.clone()).or_insert(0.0) +=
                        haversine_km(*prev_lat, *prev_lon, lat, lon);
                }
            }
            prev = Some((sid, lat, lon));
        }

        for s in &mut sessions {
            s.total_distance_km = Some(distances.get(&s.session_id).copied().unwrap_or(0.0));
        }
        Ok(sessions)
    }

    /// 获取某个会话的所有轨迹点
    pub fn get_session_track_points(&self, session_id: &str) -> Result<Vec<TrackPoint>, AppError> {
        let conn = self.pool()?;
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
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(points)
    }

    /// 删除一个会话及其所有轨迹点
    pub fn delete_session(&self, session_id: &str) -> Result<usize, AppError> {
        let conn = self.pool()?;
        let deleted = conn.execute(
            "DELETE FROM track_points WHERE session_id = ?1",
            [session_id],
        )?;
        Ok(deleted)
    }

    /// 获取会话实时统计（使用子查询获取最新轨迹点的经纬度）
    pub fn get_session_stats(&self, session_id: &str) -> Result<Option<SessionStats>, AppError> {
        let conn = self.pool()?;
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

#[cfg(test)]
mod tests {
    use crate::db::Database;
    use crate::models::TrackPointInput;

    /// 创建临时文件数据库（连接池多连接共享同一文件）
    fn test_db() -> Database {
        let path = std::env::temp_dir().join(format!(
            "record-api-session-test-{}.db",
            uuid::Uuid::new_v4()
        ));
        Database::new(path.to_str().unwrap()).unwrap()
    }

    fn point(lat: f64, lon: f64, ts: &str) -> TrackPointInput {
        TrackPointInput {
            session_id: None,
            latitude: lat,
            longitude: lon,
            altitude: None,
            speed: None,
            steps: None,
            timestamp: ts.to_string(),
        }
    }

    #[test]
    fn get_sessions_should_calculate_total_distance() {
        let db = test_db();
        // 北京 → 上海 三个点（直线约 1067 km，分两段累计）
        db.insert_track_point("s1", &point(39.9042, 116.4074, "2026-08-12 10:00:00"))
            .unwrap();
        db.insert_track_point("s1", &point(35.5000, 118.5000, "2026-08-12 10:10:00"))
            .unwrap();
        db.insert_track_point("s1", &point(31.2304, 121.4737, "2026-08-12 10:20:00"))
            .unwrap();

        let sessions = db.get_sessions().unwrap();
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].point_count, 3);
        assert_eq!(sessions[0].start_time, "2026-08-12 10:00:00");
        assert_eq!(sessions[0].end_time, "2026-08-12 10:20:00");
        let total = sessions[0].total_distance_km.unwrap();
        assert!((total - 1067.0).abs() < 40.0, "got {total}");
    }

    #[test]
    fn get_sessions_should_return_empty_for_no_points() {
        let db = test_db();
        assert!(db.get_sessions().unwrap().is_empty());
    }
}
