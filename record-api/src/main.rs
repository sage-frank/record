mod db;
mod handlers;
mod models;
mod signature;

use axum::{
    routing::{delete, get, post, put},
    Router,
};
use std::sync::Arc;
use std::time::Duration;
use time::macros::format_description;
use time::UtcOffset;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing::{info, info_span};
use tracing_subscriber::EnvFilter;

use db::Database;
use handlers::*;
use signature::{signature_middleware, SignatureState};

#[tokio::main]
async fn main() {
    // 初始化日志（东八区时间格式，不带 T 和 Z）
    let timer = tracing_subscriber::fmt::time::OffsetTime::new(
        UtcOffset::from_hms(8, 0, 0).expect("Invalid UTC offset"),
        format_description!("[year]-[month]-[day] [hour]:[minute]:[second].[subsecond digits:3]"),
    );
    
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_target(false)
        .with_timer(timer)
        .init();

    // 初始化数据库
    let database = Database::new("record.db").expect("Failed to init database");
    let db_state: AppState = Arc::new(database);
    
    // 初始化签名状态
    let signature_state = SignatureState::new();

    // CORS 配置 - 允许所有来源（开发环境）
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // 路由配置 - sessions 子路由需要 clone state（axum 不会自动传递）
    let sessions_routes = Router::new()
        .route("/", get(get_sessions))
        .route("/{id}", delete(delete_session))
        .route("/{id}/track-points", get(get_session_track_points))
        .route("/{id}/stats", get(get_session_stats))
        .with_state(db_state.clone());

    // 统一结构化请求日志
    let trace_layer = TraceLayer::new_for_http()
        .make_span_with(|request: &axum::http::Request<_>| {
            info_span!(
                "api",
                method = %request.method(),
                path = request.uri().path(),
                query = request.uri().query().unwrap_or(""),
            )
        })
        .on_response(
            |response: &axum::http::Response<_>, latency: Duration, _span: &tracing::Span| {
                let status = response.status().as_u16();
                let body_size = response
                    .headers()
                    .get("content-length")
                    .and_then(|v| v.to_str().ok())
                    .unwrap_or("-");
                info!(
                    status = status,
                    latency_ms = latency.as_millis() as u64,
                    body_bytes = body_size,
                    "completed"
                );
            },
        );

    let app = Router::new()
        .route("/api/track-points", post(add_track_point))
        .route("/api/track-points/batch", post(add_track_points_batch))
        .nest("/api/sessions", sessions_routes)
        // 减重模块
        .route("/api/profile", get(get_profile).put(update_profile))
        .route(
            "/api/weight-history",
            get(get_weight_history).post(add_weight_record),
        )
        .route("/api/weight-history/{id}", delete(delete_weight_record))
        .route(
            "/api/diet-records",
            get(get_diet_records).post(add_diet_record),
        )
        .route("/api/diet-records/{id}", delete(delete_diet_record))
        .route("/api/plans", get(get_plans).post(add_plan))
        .route("/api/plans/{id}", put(update_plan).delete(delete_plan))
        // 签名验证中间件 - 保护所有API路由
        .layer(axum::middleware::from_fn_with_state(signature_state.clone(), signature_middleware))
        .layer(cors)
        .layer(trace_layer)
        .with_state(db_state);

    let addr = "0.0.0.0:3001";
    info!("Server running at http://{addr}");
    info!("API base: http://{addr}/api");

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
