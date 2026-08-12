use crate::error::AppError;
use crate::models::error_log::{ErrorLog, ErrorLogInput, ErrorLogQuery};

use super::Database;

impl Database {
    /// 初始化异常日志表
    pub(crate) fn init_error_logs(&self) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS error_logs (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                request_id  TEXT NOT NULL,
                level       TEXT NOT NULL,
                source      TEXT NOT NULL DEFAULT '',
                message     TEXT NOT NULL,
                stack_trace TEXT,
                context     TEXT,
                platform    TEXT,
                app_version TEXT,
                device_id   TEXT,
                url         TEXT,
                created_at  TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_error_logs_request_id ON error_logs(request_id);
            CREATE INDEX IF NOT EXISTS idx_error_logs_level ON error_logs(level);
            CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at);",
        )?;
        Ok(())
    }

    /// 插入一条异常日志
    pub fn insert_error_log(&self, input: &ErrorLogInput) -> Result<ErrorLog, AppError> {
        let conn = self.lock()?;
        conn.execute(
            "INSERT INTO error_logs (request_id, level, source, message, stack_trace, context, platform, app_version, device_id, url)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            rusqlite::params![
                input.request_id,
                input.level,
                input.source,
                input.message,
                input.stack_trace,
                input.context.as_ref().map(|v| v.to_string()),
                input.platform,
                input.app_version,
                input.device_id,
                input.url,
            ],
        )?;
        let id = conn.last_insert_rowid();
        let created_at: String = conn.query_row(
            "SELECT created_at FROM error_logs WHERE id = ?1",
            [id],
            |row| row.get(0),
        )?;
        Ok(ErrorLog {
            id,
            request_id: input.request_id.clone(),
            level: input.level.clone(),
            source: input.source.clone(),
            message: input.message.clone(),
            stack_trace: input.stack_trace.clone(),
            context: input.context.as_ref().map(|v| v.to_string()),
            platform: input.platform.clone(),
            app_version: input.app_version.clone(),
            device_id: input.device_id.clone(),
            url: input.url.clone(),
            created_at,
        })
    }

    /// 查询异常日志（level/request_id/source/关键词/时间范围过滤 + 分页），
    /// 返回 (当前页日志, 总数)
    pub fn query_error_logs(&self, q: &ErrorLogQuery) -> Result<(Vec<ErrorLog>, i64), AppError> {
        let conn = self.lock()?;

        let mut clauses: Vec<String> = Vec::new();
        let mut params: Vec<rusqlite::types::Value> = Vec::new();

        if let Some(level) = q.level.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("level = ?".to_string());
            params.push(level.to_string().into());
        }
        if let Some(request_id) = q.request_id.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("request_id = ?".to_string());
            params.push(request_id.to_string().into());
        }
        if let Some(source) = q.source.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("source = ?".to_string());
            params.push(source.to_string().into());
        }
        if let Some(keyword) = q.keyword.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("(message LIKE ? OR stack_trace LIKE ? OR request_id LIKE ?)".to_string());
            let pattern = format!("%{keyword}%");
            params.push(pattern.clone().into());
            params.push(pattern.clone().into());
            params.push(pattern.into());
        }
        if let Some(start) = q.start.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("created_at >= ?".to_string());
            params.push(start.to_string().into());
        }
        if let Some(end) = q.end.as_deref().filter(|s| !s.is_empty()) {
            clauses.push("created_at <= ?".to_string());
            params.push(end.to_string().into());
        }

        let where_sql = if clauses.is_empty() {
            String::new()
        } else {
            format!(" WHERE {}", clauses.join(" AND "))
        };

        let total: i64 = conn.query_row(
            &format!("SELECT COUNT(*) FROM error_logs{where_sql}"),
            rusqlite::params_from_iter(params.iter()),
            |row| row.get(0),
        )?;

        let limit = q.page_size.clamp(1, 100);
        let offset = (q.page.max(1) - 1) * limit;
        let mut data_params: Vec<rusqlite::types::Value> = params.clone();
        data_params.push(limit.into());
        data_params.push(offset.into());

        let mut stmt = conn.prepare(&format!(
            "SELECT id, request_id, level, source, message, stack_trace, context, platform,
                    app_version, device_id, url, created_at
             FROM error_logs{where_sql}
             ORDER BY id DESC
             LIMIT ? OFFSET ?"
        ))?;
        let logs = stmt
            .query_map(
                rusqlite::params_from_iter(data_params.iter()),
                error_log_from_row,
            )?
            .filter_map(|r| r.ok())
            .collect();
        Ok((logs, total))
    }

    /// 获取单条异常日志详情
    pub fn get_error_log(&self, id: i64) -> Result<Option<ErrorLog>, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare(
            "SELECT id, request_id, level, source, message, stack_trace, context, platform,
                    app_version, device_id, url, created_at
             FROM error_logs WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map([id], error_log_from_row)?;
        match rows.next() {
            Some(r) => Ok(Some(r?)),
            None => Ok(None),
        }
    }
}

/// 将 SQLite 行映射为 ErrorLog
fn error_log_from_row(row: &rusqlite::Row) -> rusqlite::Result<ErrorLog> {
    Ok(ErrorLog {
        id: row.get(0)?,
        request_id: row.get(1)?,
        level: row.get(2)?,
        source: row.get(3)?,
        message: row.get(4)?,
        stack_trace: row.get(5)?,
        context: row.get(6)?,
        platform: row.get(7)?,
        app_version: row.get(8)?,
        device_id: row.get(9)?,
        url: row.get(10)?,
        created_at: row.get(11)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_input(request_id: &str, level: &str, source: &str, message: &str) -> ErrorLogInput {
        ErrorLogInput {
            request_id: request_id.to_string(),
            level: level.to_string(),
            source: source.to_string(),
            message: message.to_string(),
            stack_trace: Some("stack".to_string()),
            context: Some(serde_json::json!({"op": "test"})),
            platform: Some("linux".to_string()),
            app_version: Some("3.0.0".to_string()),
            device_id: Some("dev-1".to_string()),
            url: Some("/api/errors".to_string()),
        }
    }

    #[test]
    fn insert_and_get_error_log_should_round_trip() {
        let db = Database::new(":memory:").unwrap();
        let inserted = db
            .insert_error_log(&sample_input("req-1", "error", "test", "boom"))
            .unwrap();
        assert_eq!(inserted.request_id, "req-1");

        let got = db.get_error_log(inserted.id).unwrap().unwrap();
        assert_eq!(got.message, "boom");
        assert_eq!(got.level, "error");
        assert_eq!(got.context.as_deref(), Some(r#"{"op":"test"}"#));
        assert!(!got.created_at.is_empty());
    }

    #[test]
    fn query_error_logs_should_filter_by_level_and_keyword() {
        let db = Database::new(":memory:").unwrap();
        db.insert_error_log(&sample_input("req-1", "error", "app", "connection refused"))
            .unwrap();
        db.insert_error_log(&sample_input("req-2", "warning", "app", "slow response"))
            .unwrap();
        db.insert_error_log(&sample_input("req-3", "error", "web", "timeout"))
            .unwrap();

        let q = ErrorLogQuery {
            level: Some("error".into()),
            ..Default::default()
        };
        let (logs, total) = db.query_error_logs(&q).unwrap();
        assert_eq!(total, 2);
        assert!(logs.iter().all(|l| l.level == "error"));

        let q = ErrorLogQuery {
            keyword: Some("refused".into()),
            ..Default::default()
        };
        let (logs, _) = db.query_error_logs(&q).unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].request_id, "req-1");
    }

    #[test]
    fn query_error_logs_should_respect_pagination() {
        let db = Database::new(":memory:").unwrap();
        for i in 0..5 {
            db.insert_error_log(&sample_input(&format!("req-{i}"), "error", "app", "x"))
                .unwrap();
        }
        let q = ErrorLogQuery {
            page: 1,
            page_size: 2,
            ..Default::default()
        };
        let (logs, total) = db.query_error_logs(&q).unwrap();
        assert_eq!(total, 5);
        assert_eq!(logs.len(), 2);
        // 按 id 倒序：第一页应为 req-4, req-3
        assert_eq!(logs[0].request_id, "req-4");
        assert_eq!(logs[1].request_id, "req-3");
    }

    #[test]
    fn get_error_log_should_return_none_for_missing_id() {
        let db = Database::new(":memory:").unwrap();
        assert!(db.get_error_log(999).unwrap().is_none());
    }
}
