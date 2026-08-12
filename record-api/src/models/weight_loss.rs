use serde::{Deserialize, Serialize};

// ── 减重模块 ──────────────────────────────────────

/// 用户档案
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    pub name: String,
    pub current_weight_kg: f64,
    pub target_weight_kg: f64,
    pub height_cm: f64,
    pub age: i32,
    pub gender: String,
    pub daily_calorie_goal: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

/// 体重记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeightRecord {
    pub id: i64,
    pub weight_kg: f64,
    pub recorded_at: String,
}

#[derive(Debug, Deserialize)]
pub struct WeightRecordInput {
    pub weight_kg: f64,
}

/// 饮食记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DietRecord {
    pub id: String,
    pub date: String,
    pub meal_type: String,
    pub food_name: String,
    pub calories: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub protein_g: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub carbs_g: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fat_g: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct DietRecordInput {
    pub id: String,
    pub date: String,
    pub meal_type: String,
    pub food_name: String,
    pub calories: f64,
    pub protein_g: Option<f64>,
    pub carbs_g: Option<f64>,
    pub fat_g: Option<f64>,
}

/// 运动计划
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExercisePlan {
    pub id: String,
    pub name: String,
    pub description: String,
    pub target_duration_min: i32,
    pub target_distance_km: f64,
    pub target_calories: i32,
    pub weekdays: Vec<i32>,
    pub is_active: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ExercisePlanInput {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default = "default_duration")]
    pub target_duration_min: i32,
    #[serde(default = "default_distance")]
    pub target_distance_km: f64,
    #[serde(default = "default_calories")]
    pub target_calories: i32,
    #[serde(default = "default_weekdays")]
    pub weekdays: Vec<i32>,
    #[serde(default = "default_true")]
    pub is_active: bool,
}

fn default_duration() -> i32 {
    30
}
fn default_distance() -> f64 {
    5.0
}
fn default_calories() -> i32 {
    300
}
fn default_weekdays() -> Vec<i32> {
    vec![1, 3, 5]
}
fn default_true() -> bool {
    true
}
