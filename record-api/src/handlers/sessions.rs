use axum::{extract::Path, extract::State, Json};
use tracing::{debug, info};

use crate::error::AppError;

use super::{blocking, AppState};

/// GET /api/sessions
pub async fn get_sessions(State(db): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
    let sessions = blocking({
        let db = db.clone();
        move || db.get_sessions()
    })
    .await?;
    debug!("sessions_list count={}", sessions.len());
    Ok(Json(serde_json::json!({"sessions": sessions})))
}

/// GET /api/sessions/:id/track-points
pub async fn get_session_track_points(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let points = blocking({
        let db = db.clone();
        let session_id = session_id.clone();
        move || db.get_session_track_points(&session_id)
    })
    .await?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "point_count": points.len(), "points": points}),
    ))
}

/// GET /api/sessions/:id/stats
pub async fn get_session_stats(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let stats = blocking({
        let db = db.clone();
        let session_id = session_id.clone();
        move || db.get_session_stats(&session_id)
    })
    .await?;
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
    let deleted = blocking({
        let db = db.clone();
        let session_id = session_id.clone();
        move || db.delete_session(&session_id)
    })
    .await?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "deleted_count": deleted}),
    ))
}
