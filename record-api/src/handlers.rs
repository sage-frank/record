use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use tracing::{error, info};
use uuid::Uuid;

use crate::db::Database;
use crate::models::{BatchTrackPoints, TrackPointInput};

pub type AppState = std::sync::Arc<Database>;

/// POST /api/track-points
pub async fn add_track_point(
    State(db): State<AppState>,
    Json(input): Json<TrackPointInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    // 输入校验
    if let Err(errors) = input.validate() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({
                "error": "validation failed",
                "details": errors,
            })),
        ));
    }

    let session_id = input
        .session_id
        .clone()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    info!(
        "POST /api/track-points session={session_id} lat={} lng={} speed={:?} steps={:?}",
        input.latitude, input.longitude, input.speed, input.steps
    );
    let point = db
        .insert_track_point(&session_id, &input)
        .map_err(|e| internal_error("insert error", e))?;

    Ok(Json(serde_json::json!({
        "session_id": point.session_id,
        "point": point,
    })))
}

/// POST /api/track-points/batch
pub async fn add_track_points_batch(
    State(db): State<AppState>,
    Json(batch): Json<BatchTrackPoints>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    // 校验批量数据中的每个点
    let mut validation_errors: Vec<serde_json::Value> = Vec::new();
    for (i, point) in batch.points.iter().enumerate() {
        if let Err(errors) = point.validate() {
            validation_errors.push(serde_json::json!({
                "index": i,
                "errors": errors,
            }));
        }
    }
    if !validation_errors.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({
                "error": "validation failed",
                "details": validation_errors,
            })),
        ));
    }

    let session_id = if batch.session_id.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        batch.session_id.clone()
    };
    info!(
        "POST /api/track-points/batch session={session_id} point_count={}",
        batch.points.len()
    );

    let points = db
        .insert_track_points_batch(&session_id, &batch.points)
        .map_err(|e| internal_error("batch insert error", e))?;

    info!(
        "batch insert OK session={session_id} inserted={}",
        points.len()
    );
    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "point_count": points.len(),
    })))
}

/// GET /api/sessions
pub async fn get_sessions(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let sessions = db
        .get_sessions()
        .map_err(|e| internal_error("get sessions error", e))?;

    info!("GET /api/sessions count={}", sessions.len());
    Ok(Json(serde_json::json!({
        "sessions": sessions,
    })))
}

/// GET /api/sessions/:id/track-points
pub async fn get_session_track_points(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    info!("GET /api/sessions/{session_id}/track-points");
    let points = db
        .get_session_track_points(&session_id)
        .map_err(|e| internal_error("get points error", e))?;

    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "point_count": points.len(),
        "points": points,
    })))
}

/// GET /api/sessions/:id/stats - 实时统计
pub async fn get_session_stats(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let stats = db
        .get_session_stats(&session_id)
        .map_err(|e| internal_error("get stats error", e))?;

    match stats {
        Some(s) => Ok(Json(serde_json::json!({
            "found": true,
            "stats": s,
        }))),
        None => Ok(Json(serde_json::json!({
            "found": false,
            "message": "session not found",
        }))),
    }
}

/// DELETE /api/sessions/:id
pub async fn delete_session(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    info!("DELETE /api/sessions/{session_id}");
    let deleted = db
        .delete_session(&session_id)
        .map_err(|e| internal_error("delete error", e))?;

    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "deleted_count": deleted,
    })))
}

/// 将数据库错误转为 500 Internal Server Error
fn internal_error(
    context: &str,
    e: impl std::fmt::Display,
) -> (StatusCode, Json<serde_json::Value>) {
    error!("{context}: {e}");
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({"error": "internal server error"})),
    )
}
