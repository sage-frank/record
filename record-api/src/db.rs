use rusqlite::{Connection, Result};
use std::sync::Mutex;

use crate::models::{
    DietRecord, DietRecordInput, ErrorLog, ErrorLogInput, ErrorLogQuery, ExercisePlan,
    ExercisePlanInput, SessionStats, SessionSummary, TrackPoint, TrackPointInput, UserProfile,
    WeightRecord, WeightRecordInput,
};

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

/// 将 SQLite 行映射为 ErrorLog
fn error_log_from_row(row: &rusqlite::Row) -> rusqlite::Result<ErrorLog> {
    Ok(ErrorLog {
        id: row.get(0)?,
        request_id: row.get(1)?,
        level: row.get(2)?,
        source: row.get(3)?,
        message: row.get(4)?,
        stack_trace: row.get(5)?,
        context: row.get(6)?,
        platform: row.get(7)?,
        app_version: row.get(8)?,
        device_id: row.get(9)?,
        url: row.get(10)?,
        created_at: row.get(11)?,
    })
}

impl Database {
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = Database {
            conn: Mutex::new(conn),
        };

        // db.init_tables()?;
        // db.migrate_add_steps()?;
        // db.init_weight_loss_tables()?;
        db.init_error_logs()?;
        Ok(db)
    }

    // fn init_tables(&self) -> Result<()> {
    //     let conn = self.conn.lock().expect("database lock poisoned");
    //     conn.execute_batch(
    //         "CREATE TABLE IF NOT EXISTS track_points (
    //             id          INTEGER PRIMARY KEY AUTOINCREMENT,
    //             session_id  TEXT NOT NULL,
    //             latitude    REAL NOT NULL,
    //             longitude   REAL NOT NULL,
    //             altitude    REAL,
    //             speed       REAL,
    //             steps       INTEGER DEFAULT 0,
    //             timestamp   TEXT NOT NULL,
    //             created_at  TEXT NOT NULL DEFAULT (datetime('now'))
    //         );
    //         CREATE INDEX IF NOT EXISTS idx_track_points_session
    //             ON track_points(session_id);
    //         CREATE INDEX IF NOT EXISTS idx_track_points_timestamp
    //             ON track_points(session_id, timestamp);",
    //     )?;
    //     Ok(())
    // }

    // /// 初始化减重模块表
    // fn init_weight_loss_tables(&self) -> Result<()> {
    //     let conn = self.conn.lock().expect("database lock poisoned");
    //     conn.execute_batch(
    //         "CREATE TABLE IF NOT EXISTS user_profile (
    //             id                  INTEGER PRIMARY KEY DEFAULT 1,
    //             name                TEXT NOT NULL DEFAULT '',
    //             current_weight_kg   REAL NOT NULL DEFAULT 70,
    //             target_weight_kg    REAL NOT NULL DEFAULT 60,
    //             height_cm           REAL NOT NULL DEFAULT 170,
    //             age                 INTEGER NOT NULL DEFAULT 30,
    //             gender              TEXT NOT NULL DEFAULT 'male',
    //             daily_calorie_goal  INTEGER NOT NULL DEFAULT 2000,
    //             updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
    //         );
    //         INSERT OR IGNORE INTO user_profile (id) VALUES (1);

    //         CREATE TABLE IF NOT EXISTS weight_history (
    //             id          INTEGER PRIMARY KEY AUTOINCREMENT,
    //             weight_kg   REAL NOT NULL,
    //             recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
    //         );

    //         CREATE TABLE IF NOT EXISTS diet_records (
    //             id          TEXT PRIMARY KEY,
    //             date        TEXT NOT NULL,
    //             meal_type   TEXT NOT NULL,
    //             food_name   TEXT NOT NULL,
    //             calories    REAL NOT NULL DEFAULT 0,
    //             protein_g   REAL DEFAULT 0,
    //             carbs_g     REAL DEFAULT 0,
    //             fat_g       REAL DEFAULT 0,
    //             created_at  TEXT NOT NULL DEFAULT (datetime('now'))
    //         );
    //         CREATE INDEX IF NOT EXISTS idx_diet_date ON diet_records(date);

    //         CREATE TABLE IF NOT EXISTS exercise_plans (
    //             id                  TEXT PRIMARY KEY,
    //             name                TEXT NOT NULL,
    //             description         TEXT DEFAULT '',
    //             target_duration_min INTEGER DEFAULT 30,
    //             target_distance_km  REAL DEFAULT 5,
    //             target_calories     INTEGER DEFAULT 300,
    //             weekdays            TEXT NOT NULL DEFAULT '[1,3,5]',
    //             is_active           INTEGER NOT NULL DEFAULT 1,
    //             created_at          TEXT NOT NULL DEFAULT (datetime('now'))
    //         );",
    //     )?;
    //     Ok(())
    // }

    // /// 兼容旧数据库：添加 steps 列（使用 PRAGMA 检测）
    // fn migrate_add_steps(&self) -> Result<()> {
    //     let conn = self.conn.lock().expect("database lock poisoned");
    //     let mut stmt = conn.prepare("PRAGMA table_info(track_points)")?;
    //     let has_steps = stmt
    //         .query_map([], |row| row.get::<_, String>(1))?
    //         .filter_map(|r| r.ok())
    //         .any(|name| name == "steps");
    //     if !has_steps {
    //         conn.execute_batch("ALTER TABLE track_points ADD COLUMN steps INTEGER DEFAULT 0;")?;
    //     }
    //     Ok(())
    // }

    /// 初始化异常日志表
    fn init_error_logs(&self) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS error_logs (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                request_id  TEXT NOT NULL,
                level       TEXT NOT NULL,
                source      TEXT NOT NULL DEFAULT '',
                message     TEXT NOT NULL,
                stack_trace TEXT,
                context     TEXT,
                platform    TEXT,
                app_version TEXT,
                device_id   TEXT,
                url         TEXT,
                created_at  TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_error_logs_request_id ON error_logs(request_id);
            CREATE INDEX IF NOT EXISTS idx_error_logs_level ON error_logs(level);
            CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at);",
        )?;
        Ok(())
    }

    /// 插入一条异常日志
    pub fn insert_error_log(&self, input: &ErrorLogInput) -> Result<ErrorLog> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute(
            "INSERT INTO error_logs (request_id, level, source, message, stack_trace, context, platform, app_version, device_id, url)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            rusqlite::params![
                input.request_id,
                input.level,
                input.source,
                input.message,
                input.stack_trace,
                input.context.as_ref().map(|v| v.to_string()),
                input.platform,
                input.app_version,
                input.device_id,
                input.url,
            ],
        )?;
        let id = conn.last_insert_rowid();
        let created_at: String = conn.query_row(
            "SELECT created_at FROM error_logs WHERE id = ?1",
            [id],
            |row| row.get(0),
        )?;
        Ok(ErrorLog {
            id,
            request_id: input.request_id.clone(),
            level: input.level.clone(),
            source: input.source.clone(),
            message: input.message.clone(),
            stack_trace: input.stack_trace.clone(),
            context: input.context.as_ref().map(|v| v.to_string()),
            platform: input.platform.clone(),
            app_version: input.app_version.clone(),
            device_id: input.device_id.clone(),
            url: input.url.clone(),
            created_at,
        })
    }

    /// 查询异常日志（level/request_id/source/关键词/时间范围过滤 + 分页），
    /// 返回 (当前页日志, 总数)
    pub fn query_error_logs(&self, q: &ErrorLogQuery) -> Result<(Vec<ErrorLog>, i64)> {
        let conn = self.conn.lock().expect("database lock poisoned");

        let mut clauses: Vec<String> = Vec::new();
        let mut params: Vec<rusqlite::types::Value> = Vec::new();

        if let Some(level) = q.level.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("level = ?".to_string());
            params.push(level.to_string().into());
        }
        if let Some(request_id) = q.request_id.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("request_id = ?".to_string());
            params.push(request_id.to_string().into());
        }
        if let Some(source) = q.source.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("source = ?".to_string());
            params.push(source.to_string().into());
        }
        if let Some(keyword) = q.keyword.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("(message LIKE ? OR stack_trace LIKE ? OR request_id LIKE ?)".to_string());
            let pattern = format!("%{keyword}%");
            params.push(pattern.clone().into());
            params.push(pattern.clone().into());
            params.push(pattern.into());
        }
        if let Some(start) = q.start.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("created_at >= ?".to_string());
            params.push(start.to_string().into());
        }
        if let Some(end) = q.end.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("created_at <= ?".to_string());
            params.push(end.to_string().into());
        }

        let where_sql = if clauses.is_empty() {
            String::new()
        } else {
            format!(" WHERE {}", clauses.join(" AND "))
        };

        let total: i64 = conn.query_row(
            &format!("SELECT COUNT(*) FROM error_logs{where_sql}"),
            rusqlite::params_from_iter(params.iter()),
            |row| row.get(0),
        )?;

        let limit = q.page_size.clamp(1, 100);
        let offset = (q.page.max(1) - 1) * limit;
        let mut data_params: Vec<rusqlite::types::Value> = params.clone();
        data_params.push(limit.into());
        data_params.push(offset.into());

        let mut stmt = conn.prepare(&format!(
            "SELECT id, request_id, level, source, message, stack_trace, context, platform,
                    app_version, device_id, url, created_at
             FROM error_logs{where_sql}
             ORDER BY id DESC
             LIMIT ? OFFSET ?"
        ))?;
        let logs = stmt
            .query_map(
                rusqlite::params_from_iter(data_params.iter()),
                error_log_from_row,
            )?
            .filter_map(|r| r.ok())
            .collect();
        Ok((logs, total))
    }

    /// 获取单条异常日志详情
    pub fn get_error_log(&self, id: i64) -> Result<Option<ErrorLog>> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let mut stmt = conn.prepare(
            "SELECT id, request_id, level, source, message, stack_trace, context, platform,
                    app_version, device_id, url, created_at
             FROM error_logs WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map([id], error_log_from_row)?;
        match rows.next() {
            Some(r) => Ok(Some(r?)),
            None => Ok(None),
        }
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

    // ── 减重模块 ────────────────────────────────

    pub fn get_profile(&self) -> Result<UserProfile> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let mut stmt = conn.prepare(
            "SELECT name, current_weight_kg, target_weight_kg, height_cm, age, gender, daily_calorie_goal, updated_at FROM user_profile WHERE id = 1"
        )?;
        let profile = stmt.query_row([], |row| {
            Ok(UserProfile {
                name: row.get(0)?,
                current_weight_kg: row.get(1)?,
                target_weight_kg: row.get(2)?,
                height_cm: row.get(3)?,
                age: row.get(4)?,
                gender: row.get(5)?,
                daily_calorie_goal: row.get(6)?,
                updated_at: Some(row.get(7)?),
            })
        })?;
        Ok(profile)
    }

    pub fn update_profile(&self, profile: &UserProfile) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute(
            "UPDATE user_profile SET name=?1, current_weight_kg=?2, target_weight_kg=?3, height_cm=?4, age=?5, gender=?6, daily_calorie_goal=?7, updated_at=datetime('now') WHERE id=1",
            rusqlite::params![profile.name, profile.current_weight_kg, profile.target_weight_kg, profile.height_cm, profile.age, profile.gender, profile.daily_calorie_goal],
        )?;
        Ok(())
    }

    pub fn get_weight_history(&self) -> Result<Vec<WeightRecord>> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let mut stmt = conn.prepare("SELECT id, weight_kg, recorded_at FROM weight_history ORDER BY recorded_at DESC LIMIT 90")?;
        let result: Vec<WeightRecord> = stmt
            .query_map([], |row| {
                Ok(WeightRecord {
                    id: row.get(0)?,
                    weight_kg: row.get(1)?,
                    recorded_at: row.get(2)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_weight_record(&self, input: &WeightRecordInput) -> Result<WeightRecord> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute(
            "INSERT INTO weight_history (weight_kg) VALUES (?1)",
            [input.weight_kg],
        )?;
        let id = conn.last_insert_rowid();
        Ok(WeightRecord {
            id,
            weight_kg: input.weight_kg,
            recorded_at: String::new(),
        })
    }

    pub fn delete_weight_record(&self, id: i64) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute("DELETE FROM weight_history WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn get_diet_records(&self, date: Option<&str>) -> Result<Vec<DietRecord>> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let sql = "SELECT id, date, meal_type, food_name, calories, protein_g, carbs_g, fat_g, created_at FROM diet_records";
        if let Some(d) = date {
            let mut stmt =
                conn.prepare(&format!("{sql} WHERE date = ?1 ORDER BY created_at DESC"))?;
            return Ok(stmt
                .query_map([d], |row| {
                    Ok(DietRecord {
                        id: row.get(0)?,
                        date: row.get(1)?,
                        meal_type: row.get(2)?,
                        food_name: row.get(3)?,
                        calories: row.get(4)?,
                        protein_g: row.get(5)?,
                        carbs_g: row.get(6)?,
                        fat_g: row.get(7)?,
                        created_at: row.get(8)?,
                    })
                })?
                .filter_map(|r| r.ok())
                .collect());
        }
        let mut stmt = conn.prepare(&format!("{sql} ORDER BY created_at DESC LIMIT 100"))?;
        let result: Vec<DietRecord> = stmt
            .query_map([], |row| {
                Ok(DietRecord {
                    id: row.get(0)?,
                    date: row.get(1)?,
                    meal_type: row.get(2)?,
                    food_name: row.get(3)?,
                    calories: row.get(4)?,
                    protein_g: row.get(5)?,
                    carbs_g: row.get(6)?,
                    fat_g: row.get(7)?,
                    created_at: row.get(8)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_diet_record(&self, input: &DietRecordInput) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute(
            "INSERT OR REPLACE INTO diet_records (id, date, meal_type, food_name, calories, protein_g, carbs_g, fat_g) VALUES (?1,?2,?3,?4,?5,?6,?7,?8)",
            rusqlite::params![input.id, input.date, input.meal_type, input.food_name, input.calories, input.protein_g, input.carbs_g, input.fat_g],
        )?;
        Ok(())
    }

    pub fn delete_diet_record(&self, id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute("DELETE FROM diet_records WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn get_plans(&self) -> Result<Vec<ExercisePlan>> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let mut stmt = conn.prepare("SELECT id, name, description, target_duration_min, target_distance_km, target_calories, weekdays, is_active, created_at FROM exercise_plans ORDER BY created_at DESC")?;
        let result: Vec<ExercisePlan> = stmt
            .query_map([], |row| {
                let w: String = row.get(6)?;
                Ok(ExercisePlan {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    target_duration_min: row.get(3)?,
                    target_distance_km: row.get(4)?,
                    target_calories: row.get(5)?,
                    weekdays: serde_json::from_str(&w).unwrap_or_default(),
                    is_active: row.get::<_, i32>(7)? != 0,
                    created_at: row.get(8)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_plan(&self, input: &ExercisePlanInput) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let w = serde_json::to_string(&input.weekdays).unwrap_or_default();
        conn.execute(
            "INSERT OR REPLACE INTO exercise_plans (id, name, description, target_duration_min, target_distance_km, target_calories, weekdays, is_active) VALUES (?1,?2,?3,?4,?5,?6,?7,?8)",
            rusqlite::params![input.id, input.name, input.description, input.target_duration_min, input.target_distance_km, input.target_calories, w, input.is_active as i32],
        )?;
        Ok(())
    }

    pub fn update_plan(&self, id: &str, input: &ExercisePlanInput) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        let w = serde_json::to_string(&input.weekdays).unwrap_or_default();
        conn.execute(
            "UPDATE exercise_plans SET name=?1, description=?2, target_duration_min=?3, target_distance_km=?4, target_calories=?5, weekdays=?6, is_active=?7 WHERE id=?8",
            rusqlite::params![input.name, input.description, input.target_duration_min, input.target_distance_km, input.target_calories, w, input.is_active as i32, id],
        )?;
        Ok(())
    }

    pub fn delete_plan(&self, id: &str) -> Result<()> {
        let conn = self.conn.lock().expect("database lock poisoned");
        conn.execute("DELETE FROM exercise_plans WHERE id = ?1", [id])?;
        Ok(())
    }
}
