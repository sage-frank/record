mod db;
mod handlers;
mod models;

use axum::{routing::get, Router};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};

use db::Database;
use handlers::*;

#[tokio::main]
async fn main() {
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
        .with_state(state);

    let addr = "0.0.0.0:3000";
    println!("🚀 Server running at http://{addr}");
    println!("📡 API base: http://{addr}/api");

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
