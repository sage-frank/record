use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use std::collections::HashMap;
use tracing::{error, info};
use uuid::Uuid;

use crate::db::Database;
use crate::models::{
    BatchTrackPoints, DietRecordInput, ExercisePlanInput, TrackPointInput, UserProfile,
    WeightRecordInput,
};

pub type AppState = std::sync::Arc<Database>;

/// POST /api/track-points
pub async fn add_track_point(
    State(db): State<AppState>,
    Json(input): Json<TrackPointInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    if let Err(errors) = input.validate() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({"error": "validation failed", "details": errors})),
        ));
    }
    let session_id = input
        .session_id
        .clone()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    info!(
        "track_point session={session_id} lat={} lng={} speed={:?} steps={:?}",
        input.latitude, input.longitude, input.speed, input.steps
    );
    let point = db
        .insert_track_point(&session_id, &input)
        .map_err(|e| internal_error("insert error", e))?;
    Ok(Json(
        serde_json::json!({"session_id": point.session_id, "point": point}),
    ))
}

/// POST /api/track-points/batch
pub async fn add_track_points_batch(
    State(db): State<AppState>,
    Json(batch): Json<BatchTrackPoints>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let mut validation_errors: Vec<serde_json::Value> = Vec::new();
    for (i, point) in batch.points.iter().enumerate() {
        if let Err(errors) = point.validate() {
            validation_errors.push(serde_json::json!({"index": i, "errors": errors}));
        }
    }
    if !validation_errors.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({"error": "validation failed", "details": validation_errors})),
        ));
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
    let points = db
        .insert_track_points_batch(&session_id, &batch.points)
        .map_err(|e| internal_error("batch insert error", e))?;
    info!(
        "batch_insert_ok session={session_id} inserted={}",
        points.len()
    );
    Ok(Json(
        serde_json::json!({"session_id": session_id, "point_count": points.len()}),
    ))
}

/// GET /api/sessions
pub async fn get_sessions(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let sessions = db
        .get_sessions()
        .map_err(|e| internal_error("get sessions error", e))?;
    info!("sessions_list count={}", sessions.len());
    Ok(Json(serde_json::json!({"sessions": sessions})))
}

/// GET /api/sessions/:id/track-points
pub async fn get_session_track_points(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let points = db
        .get_session_track_points(&session_id)
        .map_err(|e| internal_error("get points error", e))?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "point_count": points.len(), "points": points}),
    ))
}

/// GET /api/sessions/:id/stats
pub async fn get_session_stats(
    State(db): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let stats = db
        .get_session_stats(&session_id)
        .map_err(|e| internal_error("get stats error", e))?;
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    info!("session_delete id={session_id}");
    let deleted = db
        .delete_session(&session_id)
        .map_err(|e| internal_error("delete error", e))?;
    Ok(Json(
        serde_json::json!({"session_id": session_id, "deleted_count": deleted}),
    ))
}

// ── 减重模块 ──────────────────────────────────────────

/// GET /api/profile
pub async fn get_profile(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let profile = db
        .get_profile()
        .map_err(|e| internal_error("get profile error", e))?;
    Ok(Json(serde_json::json!(profile)))
}

/// PUT /api/profile
pub async fn update_profile(
    State(db): State<AppState>,
    Json(profile): Json<UserProfile>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.update_profile(&profile)
        .map_err(|e| internal_error("update profile error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// GET /api/weight-history
pub async fn get_weight_history(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let records = db
        .get_weight_history()
        .map_err(|e| internal_error("get weight error", e))?;
    Ok(Json(serde_json::json!({"records": records})))
}

/// POST /api/weight-history
pub async fn add_weight_record(
    State(db): State<AppState>,
    Json(input): Json<WeightRecordInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let record = db
        .add_weight_record(&input)
        .map_err(|e| internal_error("add weight error", e))?;
    Ok(Json(serde_json::json!({"record": record})))
}

/// DELETE /api/weight-history/:id
pub async fn delete_weight_record(
    State(db): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.delete_weight_record(id)
        .map_err(|e| internal_error("delete weight error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// GET /api/diet-records?date=2024-01-01
pub async fn get_diet_records(
    State(db): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let date = params.get("date").map(|s| s.as_str());
    let records = db
        .get_diet_records(date)
        .map_err(|e| internal_error("get diet error", e))?;
    Ok(Json(serde_json::json!({"records": records})))
}

/// POST /api/diet-records
pub async fn add_diet_record(
    State(db): State<AppState>,
    Json(input): Json<DietRecordInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.add_diet_record(&input)
        .map_err(|e| internal_error("add diet error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// DELETE /api/diet-records/:id
pub async fn delete_diet_record(
    State(db): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.delete_diet_record(&id)
        .map_err(|e| internal_error("delete diet error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// GET /api/plans
pub async fn get_plans(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let plans = db
        .get_plans()
        .map_err(|e| internal_error("get plans error", e))?;
    Ok(Json(serde_json::json!({"plans": plans})))
}

/// POST /api/plans
pub async fn add_plan(
    State(db): State<AppState>,
    Json(input): Json<ExercisePlanInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.add_plan(&input)
        .map_err(|e| internal_error("add plan error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// PUT /api/plans/:id
pub async fn update_plan(
    State(db): State<AppState>,
    Path(id): Path<String>,
    Json(input): Json<ExercisePlanInput>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.update_plan(&id, &input)
        .map_err(|e| internal_error("update plan error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// DELETE /api/plans/:id
pub async fn delete_plan(
    State(db): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    db.delete_plan(&id)
        .map_err(|e| internal_error("delete plan error", e))?;
    Ok(Json(serde_json::json!({"ok": true})))
}

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
