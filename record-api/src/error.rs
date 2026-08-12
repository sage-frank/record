use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use tracing::error;

/// 应用统一错误类型：数据库/校验/业务错误都映射为 HTTP 响应。
/// handler 通过 `?` 传播，由 IntoResponse 统一转换为 JSON 错误体。
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("database lock poisoned")]
    LockPoisoned,

    /// 参数校验失败，details 为具体错误列表
    #[error("validation failed: {0:?}")]
    Validation(Vec<String>),

    /// 参数校验失败（保留原始 details 结构，如对象数组）
    #[error("bad request: {error}")]
    BadRequest {
        error: String,
        details: serde_json::Value,
    },
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, payload) = match self {
            AppError::Validation(details) => (
                StatusCode::BAD_REQUEST,
                json!({"error": "validation failed", "details": details}),
            ),
            AppError::BadRequest { error, details } => (
                StatusCode::BAD_REQUEST,
                json!({"error": error, "details": details}),
            ),
            AppError::Database(e) => {
                error!("database error: {e}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    json!({"error": "internal server error"}),
                )
            }
            AppError::LockPoisoned => {
                error!("database mutex poisoned");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    json!({"error": "internal server error"}),
                )
            }
        };
        (status, Json(payload)).into_response()
    }
}

/// 由 handler 的校验逻辑快速构造校验错误
pub fn validation_err(errors: Vec<String>) -> AppError {
    AppError::Validation(errors)
}
