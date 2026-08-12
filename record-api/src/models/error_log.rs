use serde::{Deserialize, Serialize};

// ── 异常日志模块 ──────────────────────────────────

/// 异常日志（App 上报，类似 Sentry 的轻量实现）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorLog {
    pub id: i64,
    pub request_id: String,
    pub level: String,
    pub source: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stack_trace: Option<String>,
    /// context 在数据库中存储为 JSON 字符串
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platform: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    pub created_at: String,
}

/// 异常上报输入（App 端 POST /api/errors 请求体）
#[derive(Debug, Clone, Deserialize)]
pub struct ErrorLogInput {
    /// 客户端生成、随每次请求携带的请求 ID，用于异常与请求的关联追踪
    pub request_id: String,
    /// 级别：error / warning / info / debug
    pub level: String,
    #[serde(default)]
    pub source: String,
    pub message: String,
    #[serde(default)]
    pub stack_trace: Option<String>,
    #[serde(default)]
    pub context: Option<serde_json::Value>,
    #[serde(default)]
    pub platform: Option<String>,
    #[serde(default)]
    pub app_version: Option<String>,
    #[serde(default)]
    pub device_id: Option<String>,
    #[serde(default)]
    pub url: Option<String>,
}

/// stack_trace 最大长度（超出截断，避免撑爆数据库）
const MAX_STACK_TRACE_LEN: usize = 65536;

impl ErrorLogInput {
    /// 校验输入合法性，返回错误消息列表
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();
        if self.request_id.trim().is_empty() {
            errors.push("request_id is required".to_string());
        }
        if self.message.trim().is_empty() {
            errors.push("message is required".to_string());
        }
        if !["error", "warning", "info", "debug"].contains(&self.level.as_str()) {
            errors.push(format!(
                "level must be one of error/warning/info/debug, got {}",
                self.level
            ));
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    /// 截断过长的 stack_trace（按 UTF-8 字符边界安全截断）
    pub fn truncate_stack_trace(&mut self) {
        if let Some(st) = &mut self.stack_trace {
            if st.len() > MAX_STACK_TRACE_LEN {
                let mut end = MAX_STACK_TRACE_LEN;
                while !st.is_char_boundary(end) {
                    end -= 1;
                }
                st.truncate(end);
                st.push_str("... [truncated]");
            }
        }
    }
}

/// 异常日志查询参数（GET /api/errors）
#[derive(Debug, Default, Deserialize)]
pub struct ErrorLogQuery {
    #[serde(default)]
    pub level: Option<String>,
    #[serde(default)]
    pub request_id: Option<String>,
    #[serde(default)]
    pub source: Option<String>,
    /// 关键词，匹配 message / stack_trace / request_id
    #[serde(default)]
    pub keyword: Option<String>,
    /// created_at 起始时间（含），格式与数据库一致：YYYY-MM-DD HH:MM:SS 或日期
    #[serde(default)]
    pub start: Option<String>,
    /// created_at 结束时间（含）
    #[serde(default)]
    pub end: Option<String>,
    #[serde(default = "default_page")]
    pub page: i64,
    #[serde(default = "default_page_size")]
    pub page_size: i64,
}

fn default_page() -> i64 {
    1
}

fn default_page_size() -> i64 {
    20
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_log_input_validate_should_reject_missing_fields() {
        let input = ErrorLogInput {
            request_id: "".to_string(),
            level: "verbose".to_string(),
            source: String::new(),
            message: "  ".to_string(),
            stack_trace: None,
            context: None,
            platform: None,
            app_version: None,
            device_id: None,
            url: None,
        };
        let errors = input.validate().unwrap_err();
        assert_eq!(errors.len(), 3);
    }

    #[test]
    fn error_log_input_validate_should_accept_valid_input() {
        let input = ErrorLogInput {
            request_id: "req-1".to_string(),
            level: "error".to_string(),
            source: "test".to_string(),
            message: "boom".to_string(),
            stack_trace: None,
            context: None,
            platform: None,
            app_version: None,
            device_id: None,
            url: None,
        };
        assert!(input.validate().is_ok());
    }

    #[test]
    fn truncate_stack_trace_should_cut_long_ascii() {
        let mut input = ErrorLogInput {
            request_id: "req-1".to_string(),
            level: "error".to_string(),
            source: String::new(),
            message: "boom".to_string(),
            stack_trace: Some("a".repeat(MAX_STACK_TRACE_LEN + 1000)),
            context: None,
            platform: None,
            app_version: None,
            device_id: None,
            url: None,
        };
        input.truncate_stack_trace();
        let st = input.stack_trace.unwrap();
        assert!(st.len() <= MAX_STACK_TRACE_LEN + "... [truncated]".len());
        assert!(st.ends_with("... [truncated]"));
    }

    #[test]
    fn truncate_stack_trace_should_not_cut_multi_byte_char() {
        // 中文占 3 字节：截断边界若落在中文字符中间会 panic（String::truncate 要求字符边界）
        let mut input = ErrorLogInput {
            request_id: "req-1".to_string(),
            level: "error".to_string(),
            source: String::new(),
            message: "boom".to_string(),
            stack_trace: Some("跑".repeat(MAX_STACK_TRACE_LEN / 3 + 10)),
            context: None,
            platform: None,
            app_version: None,
            device_id: None,
            url: None,
        };
        input.truncate_stack_trace();
        let st = input.stack_trace.unwrap();
        assert!(st.len() <= MAX_STACK_TRACE_LEN + "... [truncated]".len());
        assert!(st.is_char_boundary(st.len()));
    }

    #[test]
    fn truncate_stack_trace_should_keep_short_trace_untouched() {
        let mut input = ErrorLogInput {
            request_id: "req-1".to_string(),
            level: "error".to_string(),
            source: String::new(),
            message: "boom".to_string(),
            stack_trace: Some("short".to_string()),
            context: None,
            platform: None,
            app_version: None,
            device_id: None,
            url: None,
        };
        input.truncate_stack_trace();
        assert_eq!(input.stack_trace.as_deref(), Some("short"));
    }
}
