use axum::{
    extract::{Path, Query, State},
    Json,
};
use std::collections::HashMap;

use crate::error::AppError;
use crate::models::weight_loss::{
    DietRecordInput, ExercisePlanInput, UserProfile, WeightRecordInput,
};

use super::AppState;

// ── 档案 ──────────────────────────────────────────

/// GET /api/profile
pub async fn get_profile(State(db): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
    let profile = db.get_profile()?;
    Ok(Json(serde_json::json!(profile)))
}

/// PUT /api/profile
pub async fn update_profile(
    State(db): State<AppState>,
    Json(profile): Json<UserProfile>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.update_profile(&profile)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

// ── 体重 ──────────────────────────────────────────

/// GET /api/weight-history
pub async fn get_weight_history(
    State(db): State<AppState>,
) -> Result<Json<serde_json::Value>, AppError> {
    let records = db.get_weight_history()?;
    Ok(Json(serde_json::json!({"records": records})))
}

/// POST /api/weight-history
pub async fn add_weight_record(
    State(db): State<AppState>,
    Json(input): Json<WeightRecordInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    let record = db.add_weight_record(&input)?;
    Ok(Json(serde_json::json!({"record": record})))
}

/// DELETE /api/weight-history/:id
pub async fn delete_weight_record(
    State(db): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.delete_weight_record(id)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

// ── 饮食 ──────────────────────────────────────────

/// GET /api/diet-records?date=2024-01-01
pub async fn get_diet_records(
    State(db): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<serde_json::Value>, AppError> {
    let date = params.get("date").map(|s| s.as_str());
    let records = db.get_diet_records(date)?;
    Ok(Json(serde_json::json!({"records": records})))
}

/// POST /api/diet-records
pub async fn add_diet_record(
    State(db): State<AppState>,
    Json(input): Json<DietRecordInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.add_diet_record(&input)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// DELETE /api/diet-records/:id
pub async fn delete_diet_record(
    State(db): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.delete_diet_record(&id)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

// ── 运动计划 ──────────────────────────────────────

/// GET /api/plans
pub async fn get_plans(State(db): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
    let plans = db.get_plans()?;
    Ok(Json(serde_json::json!({"plans": plans})))
}

/// POST /api/plans
pub async fn add_plan(
    State(db): State<AppState>,
    Json(input): Json<ExercisePlanInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.add_plan(&input)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// PUT /api/plans/:id
pub async fn update_plan(
    State(db): State<AppState>,
    Path(id): Path<String>,
    Json(input): Json<ExercisePlanInput>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.update_plan(&id, &input)?;
    Ok(Json(serde_json::json!({"ok": true})))
}

/// DELETE /api/plans/:id
pub async fn delete_plan(
    State(db): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    db.delete_plan(&id)?;
    Ok(Json(serde_json::json!({"ok": true})))
}
