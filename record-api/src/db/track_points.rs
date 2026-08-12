use crate::error::AppError;
use crate::models::{TrackPoint, TrackPointInput};

use super::Database;

impl Database {
    /// 插入单个轨迹点
    pub fn insert_track_point(
        &self,
        session_id: &str,
        input: &TrackPointInput,
    ) -> Result<TrackPoint, AppError> {
        let conn = self.lock()?;
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

    /// 批量插入轨迹点（包裹在事务中，失败自动回滚）
    pub fn insert_track_points_batch(
        &self,
        session_id: &str,
        points: &[TrackPointInput],
    ) -> Result<Vec<TrackPoint>, AppError> {
        let conn = self.lock()?;
        let tx = conn.unchecked_transaction()?;

        let mut results = Vec::with_capacity(points.len());
        for point in points {
            tx.execute(
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
            let id = tx.last_insert_rowid();
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
        tx.commit()?;
        Ok(results)
    }
}
