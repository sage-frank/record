use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use uuid::Uuid;

use crate::db::Database;
use crate::models::{BatchTrackPoints, TrackPointInput};

pub type AppState = std::sync::Arc<Database>;

/// POST /api/track-points
pub async fn add_track_point(
    State(db): State<AppState>,
    Json(input): Json<TrackPointInput>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let session_id = Uuid::new_v4().to_string();
    let point = db
        .insert_track_point(&session_id, &input)
        .map_err(|e| {
            eprintln!("insert error: {e}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(serde_json::json!({
        "session_id": point.session_id,
        "point": point,
    })))
}

/// POST /api/track-points/batch
pub async fn add_track_points_batch(
    State(db): State<AppState>,
    Json(batch): Json<BatchTrackPoints>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let session_id = if batch.session_id.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        batch.session_id
    };

    let points = db
        .insert_track_points_batch(&session_id, &batch.points)
        .map_err(|e| {
            eprintln!("batch insert error: {e}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "point_count": points.len(),
    })))
}

/// GET /api/sessions
pub async fn get_sessions(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let sessions = db.get_sessions().map_err(|e| {
        eprintln!("get sessions error: {e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(serde_json::json!({
        "sessions": sessions,
    })))
}

/// GET /api/sessions/:id/track-points
pub async fn get_session_track_points(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let points = db
        .get_session_track_points(&session_id)
        .map_err(|e| {
            eprintln!("get points error: {e}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "point_count": points.len(),
        "points": points,
    })))
}

/// DELETE /api/sessions/:id
pub async fn delete_session(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let deleted = db.delete_session(&session_id).map_err(|e| {
        eprintln!("delete error: {e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(serde_json::json!({
        "session_id": session_id,
        "deleted_count": deleted,
    })))
}
