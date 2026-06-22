mod db;
mod handlers;
mod models;

use axum::{routing::get, Router};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing::info;
use tracing_subscriber::EnvFilter;

use db::Database;
use handlers::*;

#[tokio::main]
async fn main() {
    // 初始化日志（带时间戳 + 日志级别过滤）
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_target(false)
        .init();

    // 初始化数据库
    let database = Database::new("record.db").expect("Failed to init database");
    let state: AppState = Arc::new(database);

    // CORS 配置 - 允许所有来源（开发环境）
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // 路由配置
    let app = Router::new()
        .route("/api/track-points", axum::routing::post(add_track_point))
        .route("/api/track-points/batch", axum::routing::post(add_track_points_batch))
        .route("/api/sessions", get(get_sessions))
        .route("/api/sessions/{id}/track-points", get(get_session_track_points))
        .route("/api/sessions/{id}/stats", get(get_session_stats))
        .route("/api/sessions/{id}", axum::routing::delete(delete_session))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = "0.0.0.0:3000";
    info!("Server running at http://{addr}");
    info!("API base: http://{addr}/api");

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
