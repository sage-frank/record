pub mod error_logs;
pub mod sessions;
pub mod track_points;
pub mod weight_loss;

use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;

use crate::error::AppError;

/// 连接池大小：SQLite 读多写少，适度并发即可
const POOL_MAX_SIZE: u32 = 8;

/// SQLite 数据库封装：r2d2 连接池 + WAL 模式。
/// 各领域模块（track_points / sessions / weight_loss / error_logs）
/// 以 `impl Database` 形式拆分到对应文件中。
pub struct Database {
    pool: r2d2::Pool<SqliteConnectionManager>,
}

/// Haversine 公式计算两点间的球面距离（km）
pub(crate) fn haversine_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    const R: f64 = 6371.0;
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();
    let a = (dlat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();
    R * c
}

impl Database {
    /// 打开（或创建）数据库：建立连接池（WAL 模式）并初始化全部表结构（幂等）
    pub fn new(path: &str) -> Result<Self, AppError> {
        let manager = SqliteConnectionManager::file(path).with_init(|conn| {
            // WAL：读写不互斥；synchronous=NORMAL：WAL 下崩溃安全且更快
            conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")?;
            Ok(())
        });
        let pool = r2d2::Pool::builder()
            .max_size(POOL_MAX_SIZE)
            .build(manager)?;
        let db = Database { pool };
        db.init_tables()?;
        db.init_weight_loss_tables()?;
        db.init_error_logs()?;
        Ok(db)
    }

    /// 从连接池获取一个连接（每个请求独立连接，互不阻塞）
    pub(crate) fn pool(&self) -> Result<PooledConnection<SqliteConnectionManager>, AppError> {
        self.pool.get().map_err(AppError::Pool)
    }

    /// 初始化轨迹点表
    fn init_tables(&self) -> Result<(), AppError> {
        let conn = self.pool()?;
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

    /// 初始化减重模块表
    fn init_weight_loss_tables(&self) -> Result<(), AppError> {
        let conn = self.pool()?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS user_profile (
                id                  INTEGER PRIMARY KEY DEFAULT 1,
                name                TEXT NOT NULL DEFAULT '',
                current_weight_kg   REAL NOT NULL DEFAULT 70,
                target_weight_kg    REAL NOT NULL DEFAULT 60,
                height_cm           REAL NOT NULL DEFAULT 170,
                age                 INTEGER NOT NULL DEFAULT 30,
                gender              TEXT NOT NULL DEFAULT 'male',
                daily_calorie_goal  INTEGER NOT NULL DEFAULT 2000,
                updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
            );
            INSERT OR IGNORE INTO user_profile (id) VALUES (1);

            CREATE TABLE IF NOT EXISTS weight_history (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                weight_kg   REAL NOT NULL,
                recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS diet_records (
                id          TEXT PRIMARY KEY,
                date        TEXT NOT NULL,
                meal_type   TEXT NOT NULL,
                food_name   TEXT NOT NULL,
                calories    REAL NOT NULL DEFAULT 0,
                protein_g   REAL DEFAULT 0,
                carbs_g     REAL DEFAULT 0,
                fat_g       REAL DEFAULT 0,
                created_at  TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_diet_date ON diet_records(date);

            CREATE TABLE IF NOT EXISTS exercise_plans (
                id                  TEXT PRIMARY KEY,
                name                TEXT NOT NULL,
                description         TEXT DEFAULT '',
                target_duration_min INTEGER DEFAULT 30,
                target_distance_km  REAL DEFAULT 5,
                target_calories     INTEGER DEFAULT 300,
                weekdays            TEXT NOT NULL DEFAULT '[1,3,5]',
                is_active           INTEGER NOT NULL DEFAULT 1,
                created_at          TEXT NOT NULL DEFAULT (datetime('now'))
            );",
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 创建临时文件数据库（连接池多连接共享同一文件；:memory: 每连接独立不适用）
    fn test_db() -> Database {
        let path =
            std::env::temp_dir().join(format!("record-api-test-{}.db", uuid::Uuid::new_v4()));
        Database::new(path.to_str().unwrap()).unwrap()
    }

    #[test]
    fn haversine_km_should_match_known_distance() {
        // 北京 → 上海 直线距离约 1067 km
        let dist = haversine_km(39.9042, 116.4074, 31.2304, 121.4737);
        assert!((dist - 1067.0).abs() < 20.0, "got {dist}");
    }

    #[test]
    fn haversine_km_should_be_zero_for_same_point() {
        assert_eq!(haversine_km(30.0, 120.0, 30.0, 120.0), 0.0);
    }

    #[test]
    fn database_new_should_create_all_tables() {
        // 新库可初始化全部表（含异常日志表），无旧表时也能直接使用
        let db = test_db();
        let n: i64 = db
            .pool()
            .unwrap()
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert!(n >= 4, "expected at least 4 tables, got {n}");
    }
}
