use axum::{
    extract::{Path, Query, State},
    Json,
};
use tracing::info;

use crate::error::{validation_err, AppError};
use crate::models::error_log::{ErrorLogInput, ErrorLogQuery};

use super::AppState;

/// POST /api/errors — App 上报异常日志（签名保护）
pub async fn add_error_log(
    State(db): State<AppState>,
    Json(mut input): Json<ErrorLogInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    input.validate().map_err(validation_err)?;
    input.truncate_stack_trace();
    let log = db.insert_error_log(&input)?;
    info!(
        "error_log_ok id={} request_id={} level={} source={}",
        log.id, log.request_id, log.level, log.source
    );
    Ok(Json(
        serde_json::json!({"id": log.id, "request_id": log.request_id}),
    ))
}

/// GET /api/errors — 查询异常日志（Web 端只读访问，签名中间件已放行）
pub async fn get_error_logs(
    State(db): State<AppState>,
    Query(query): Query<ErrorLogQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let (logs, total) = db.query_error_logs(&query)?;
    info!(
        "error_logs_query page={} page_size={} total={} returned={}",
        query.page,
        query.page_size,
        total,
        logs.len()
    );
    Ok(Json(serde_json::json!({
        "total": total,
        "page": query.page.max(1),
        "page_size": query.page_size.clamp(1, 100),
        "logs": logs,
    })))
}

/// GET /api/errors/:id — 异常日志详情
pub async fn get_error_log_detail(
    State(db): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<serde_json::Value>, AppError> {
    let log = db.get_error_log(id)?;
    match log {
        Some(log) => Ok(Json(serde_json::json!({"found": true, "log": log}))),
        None => Ok(Json(serde_json::json!({
            "found": false,
            "message": "error log not found"
        }))),
    }
}
