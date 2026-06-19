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
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: Option<f64>,
    pub speed: Option<f64>,
    pub timestamp: String,
}

/// 运动会话摘要
#[derive(Debug, Serialize)]
pub struct SessionSummary {
    pub session_id: String,
    pub start_time: String,
    pub end_time: String,
    pub point_count: i64,
    pub total_distance_km: Option<f64>,
}
