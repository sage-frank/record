use axum::{extract::State, Json};
use tracing::info;
use uuid::Uuid;

use crate::error::{validation_err, AppError};
use crate::models::{BatchTrackPoints, TrackPointInput};

use super::AppState;

/// POST /api/track-points
pub async fn add_track_point(
    State(db): State<AppState>,
    Json(input): Json<TrackPointInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    input.validate().map_err(validation_err)?;
    let session_id = input
        .session_id
        .clone()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    info!(
        "track_point session={session_id} lat={} lng={} speed={:?} steps={:?}",
        input.latitude, input.longitude, input.speed, input.steps
    );
    let point = db.insert_track_point(&session_id, &input)?;
    Ok(Json(
        serde_json::json!({"session_id": point.session_id, "point": point}),
    ))
}

/// POST /api/track-points/batch
pub async fn add_track_points_batch(
    State(db): State<AppState>,
    Json(batch): Json<BatchTrackPoints>,
) -> Result<Json<serde_json::Value>, AppError> {
    let mut validation_errors: Vec<serde_json::Value> = Vec::new();
    for (i, point) in batch.points.iter().enumerate() {
        if let Err(errors) = point.validate() {
            validation_errors.push(serde_json::json!({"index": i, "errors": errors}));
        }
    }
    if !validation_errors.is_empty() {
        return Err(AppError::BadRequest {
            error: "validation failed".to_string(),
            details: serde_json::Value::Array(validation_errors),
        });
    }
    let session_id = if batch.session_id.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        batch.session_id.clone()
    };
    info!(
        "track_points_batch session={session_id} count={}",
        batch.points.len()
    );
    let points = db.insert_track_points_batch(&session_id, &batch.points)?;
    info!(
        "batch_insert_ok session={session_id} inserted={}",
        points.len()
    );
    Ok(Json(
        serde_json::json!({"session_id": session_id, "point_count": points.len()}),
    ))
}
