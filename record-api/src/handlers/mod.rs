pub mod error_logs;
pub mod sessions;
pub mod track_points;
pub mod weight_loss;

pub use error_logs::{add_error_log, get_error_log_detail, get_error_logs};
pub use sessions::{delete_session, get_session_stats, get_session_track_points, get_sessions};
pub use track_points::{add_track_point, add_track_points_batch};
pub use weight_loss::{
    add_diet_record, add_plan, add_weight_record, delete_diet_record, delete_plan,
    delete_weight_record, get_diet_records, get_plans, get_profile, get_weight_history,
    update_plan, update_profile,
};

use crate::db::Database;

/// 共享状态：数据库连接池的 Arc 包装
pub type AppState = std::sync::Arc<Database>;
