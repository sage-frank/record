use axum::{extract::Path, extract::State, Json};
use tracing::info;

use crate::error::AppError;

use super::AppState;

/// GET /api/sessions
pub async fn get_sessions(State(db): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
    let sessions = db.get_sessions()?;
    info!("sessions_list count={}", sessions.len());
    Ok(Json(serde_json::json!({"sessions": sessions})))
}

/// GET /api/sessions/:id/track-points
pub async fn get_session_track_points(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let points = db.get_session_track_points(&session_id)?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "point_count": points.len(), "points": points}),
    ))
}

/// GET /api/sessions/:id/stats
pub async fn get_session_stats(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let stats = db.get_session_stats(&session_id)?;
    match stats {
        Some(s) => Ok(Json(serde_json::json!({"found": true, "stats": s}))),
        None => Ok(Json(
            serde_json::json!({"found": false, "message": "session not found"}),
        )),
    }
}

/// DELETE /api/sessions/:id
pub async fn delete_session(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    info!("session_delete id={session_id}");
    let deleted = db.delete_session(&session_id)?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "deleted_count": deleted}),
    ))
}
