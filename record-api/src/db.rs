use rusqlite::{Connection, Result};
use std::sync::Mutex;

use crate::models::{SessionStats, SessionSummary, TrackPoint, TrackPointInput};

pub struct Database {
    conn: Mutex<Connection>,
}

/// Haversine 公式计算两点间的球面距离（km）
fn haversine_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    const R: f64 = 6371.0;
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();
    let a = (dlat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();
    R * c
}

impl Database {
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = Database {
            conn: Mutex::new(conn),
        };
        db.init_tables()?;
        db.migrate_add_steps()?;
        Ok(db)
    }

    fn init_tables(&self) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS track_points (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id  TEXT NOT NULL,
                latitude    REAL NOT NULL,
                longitude   REAL NOT NULL,
                altitude    REAL,
                speed       REAL,
                steps       INTEGER DEFAULT 0,
                timestamp   TEXT NOT NULL,
                created_at  TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_track_points_session
                ON track_points(session_id);
            CREATE INDEX IF NOT EXISTS idx_track_points_timestamp
                ON track_points(session_id, timestamp);",
        )?;
        Ok(())
    }

    /// 兼容旧数据库：添加 steps 列（使用 PRAGMA 检测）
    fn migrate_add_steps(&self) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let mut stmt = conn.prepare("PRAGMA table_info(track_points)")?;
        let has_steps = stmt
            .query_map([], |row| row.get::<_, String>(1))?
            .filter_map(|r| r.ok())
            .any(|name| name == "steps");
        if !has_steps {
            conn.execute_batch("ALTER TABLE track_points ADD COLUMN steps INTEGER DEFAULT 0;")?;
        }
        Ok(())
    }

    /// 插入单个轨迹点
    pub fn insert_track_point(
        &self,
        session_id: &str,
        input: &TrackPointInput,
    ) -> Result<TrackPoint> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute(
            "INSERT INTO track_points (session_id, latitude, longitude, altitude, speed, steps, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![
                session_id,
                input.latitude,
                input.longitude,
                input.altitude,
                input.speed,
                input.steps,
                input.timestamp,
            ],
        )?;
        let id = conn.last_insert_rowid();
        Ok(TrackPoint {
            id: Some(id),
            session_id: session_id.to_string(),
            latitude: input.latitude,
            longitude: input.longitude,
            altitude: input.altitude,
            speed: input.speed,
            steps: input.steps,
            timestamp: input.timestamp.clone(),
            created_at: None,
        })
    }

    /// 批量插入轨迹点（包裹在事务中）
    pub fn insert_track_points_batch(
        &self,
        session_id: &str,
        points: &[TrackPointInput],
    ) -> Result<Vec<TrackPoint>> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute_batch("BEGIN IMMEDIATE")?;

        let mut results = Vec::with_capacity(points.len());
        for point in points {
            conn.execute(
                "INSERT INTO track_points (session_id, latitude, longitude, altitude, speed, steps, timestamp)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                rusqlite::params![
                    session_id,
                    point.latitude,
                    point.longitude,
                    point.altitude,
                    point.speed,
                    point.steps,
                    point.timestamp,
                ],
            )?;
            let id = conn.last_insert_rowid();
            results.push(TrackPoint {
                id: Some(id),
                session_id: session_id.to_string(),
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                speed: point.speed,
                steps: point.steps,
                timestamp: point.timestamp.clone(),
                created_at: None,
            });
        }
        conn.execute_batch("COMMIT")?;
        Ok(results)
    }

    /// 获取所有会话摘要（含距离计算）
    pub fn get_sessions(&self) -> Result<Vec<SessionSummary>> {
        // 第一步：在锁内查询摘要（不计算距离，避免死锁）
        let sessions = {
            let conn = self.conn.lock().expect("database lock poisoned");
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

        // 第二步：在锁外逐 session 计算距离
        let mut result = Vec::with_capacity(sessions.len());
        for mut s in sessions {
            s.total_distance_km = Some(self.calculate_session_distance(&s.session_id)?);
            result.push(s);
        }
        Ok(result)
    }

    /// 计算单个 session 所有轨迹点连线的总距离（km）
    fn calculate_session_distance(&self, session_id: &str) -> Result<f64> {
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
    pub fn get_session_track_points(&self, session_id: &str) -> Result<Vec<TrackPoint>> {
        let conn = self.conn.lock().expect("database lock poisoned");
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
    pub fn delete_session(&self, session_id: &str) -> Result<usize> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let deleted = conn.execute(
            "DELETE FROM track_points WHERE session_id = ?1",
            [session_id],
        )?;
        Ok(deleted)
    }

    /// 获取会话实时统计（使用子查询获取最新轨迹点的经纬度）
    pub fn get_session_stats(&self, session_id: &str) -> Result<Option<SessionStats>> {
        let conn = self.conn.lock().expect("database lock poisoned");
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
