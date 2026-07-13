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
