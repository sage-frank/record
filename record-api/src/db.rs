use rusqlite::{Connection, Result};
use std::sync::Mutex;

use crate::models::{SessionStats, SessionSummary, TrackPoint, TrackPointInput};

pub struct Database {
    conn: Mutex<Connection>,
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
        let conn = self.conn.lock().unwrap();
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

    /// 兼容旧数据库：添加 steps 列
    fn migrate_add_steps(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let has_column: bool = conn
            .prepare("SELECT steps FROM track_points LIMIT 0")
            .is_ok();
        if !has_column {
            conn.execute_batch(
                "ALTER TABLE track_points ADD COLUMN steps INTEGER DEFAULT 0;",
            )?;
        }
        Ok(())
    }

    /// 插入单个轨迹点
    pub fn insert_track_point(&self, session_id: &str, input: &TrackPointInput) -> Result<TrackPoint> {
        let conn = self.conn.lock().unwrap();
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

    /// 批量插入轨迹点
    pub fn insert_track_points_batch(
        &self,
        session_id: &str,
        points: &[TrackPointInput],
    ) -> Result<Vec<TrackPoint>> {
        let conn = self.conn.lock().unwrap();
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
        Ok(results)
    }

    /// 获取所有会话摘要
    pub fn get_sessions(&self) -> Result<Vec<SessionSummary>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT session_id, MIN(timestamp) as start_time, MAX(timestamp) as end_time, 
                    COUNT(*) as point_count, COALESCE(SUM(steps), 0) as total_steps
             FROM track_points 
             GROUP BY session_id 
             ORDER BY start_time DESC",
        )?;

        let sessions = stmt
            .query_map([], |row| {
                Ok(SessionSummary {
                    session_id: row.get(0)?,
                    start_time: row.get(1)?,
                    end_time: row.get(2)?,
                    point_count: row.get(3)?,
                    total_steps: Some(row.get(4)?),
                    total_distance_km: None,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(sessions)
    }

    /// 获取某个会话的所有轨迹点
    pub fn get_session_track_points(&self, session_id: &str) -> Result<Vec<TrackPoint>> {
        let conn = self.conn.lock().unwrap();
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
        let conn = self.conn.lock().unwrap();
        let deleted = conn.execute(
            "DELETE FROM track_points WHERE session_id = ?1",
            [session_id],
        )?;
        Ok(deleted)
    }

    /// 获取会话实时统计
    pub fn get_session_stats(&self, session_id: &str) -> Result<Option<SessionStats>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT session_id, COUNT(*), COALESCE(SUM(steps), 0), 
                    MIN(timestamp), latitude, longitude, MAX(timestamp)
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
