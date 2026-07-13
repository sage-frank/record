use serde::{Deserialize, Serialize};

/// 单个轨迹点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrackPoint {
    pub id: Option<i64>,
    pub session_id: String,
    pub latitude: f64,
    pub longitude: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub altitude: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub speed: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub steps: Option<i64>,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
}

/// 批量上报请求
#[derive(Debug, Deserialize)]
pub struct BatchTrackPoints {
    pub session_id: String,
    pub points: Vec<TrackPointInput>,
}

/// 单个轨迹点输入（上报时用）
#[derive(Debug, Deserialize)]
pub struct TrackPointInput {
    /// 可选，指定则追加到已有 session，否则自动新建
    pub session_id: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f64>,
    pub steps: Option<i64>,
    pub timestamp: String,
}

impl TrackPointInput {
    /// 校验输入合法性，返回错误消息列表
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();
        if self.latitude < -90.0 || self.latitude > 90.0 {
            errors.push(format!(
                "latitude must be between -90 and 90, got {}",
                self.latitude
            ));
        }
        if self.longitude < -180.0 || self.longitude > 180.0 {
            errors.push(format!(
                "longitude must be between -180 and 180, got {}",
                self.longitude
            ));
        }
        if self.timestamp.trim().is_empty() {
            errors.push("timestamp is required".to_string());
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

/// 运动会话摘要
#[derive(Debug, Serialize)]
pub struct SessionSummary {
    pub session_id: String,
    pub start_time: String,
    pub end_time: String,
    pub point_count: i64,
    pub total_steps: Option<i64>,
    pub total_distance_km: Option<f64>,
}

/// 实时统计信息
#[derive(Debug, Serialize)]
pub struct SessionStats {
    pub session_id: String,
    pub point_count: i64,
    pub total_steps: i64,
    pub start_time: String,
    pub last_latitude: f64,
    pub last_longitude: f64,
    pub last_timestamp: String,
}

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
