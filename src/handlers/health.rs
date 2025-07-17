use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::Arc;
use chrono::{DateTime, Utc};

use crate::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct HealthResponse {
    pub status: String,
    pub timestamp: DateTime<Utc>,
    pub version: String,
    pub environment: String,
    pub database: DatabaseHealth,
    pub uptime: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DatabaseHealth {
    pub status: String,
    pub connected: bool,
    pub pool_size: u32,
}

pub async fn health_check(
    State(state): State<Arc<AppState>>,
) -> (StatusCode, Json<serde_json::Value>) {
    match &state.db {
        Some(database) => {
            match database.health_check().await {
                Ok(_) => {
                    (
                        StatusCode::OK,
                        Json(json!({
                            "status": "healthy",
                            "timestamp": chrono::Utc::now(),
                            "version": env!("CARGO_PKG_VERSION"),
                            "database": "connected"
                        }))
                    )
                }
                Err(e) => {
                    (
                        StatusCode::SERVICE_UNAVAILABLE,
                        Json(json!({
                            "status": "unhealthy",
                            "timestamp": chrono::Utc::now(),
                            "version": env!("CARGO_PKG_VERSION"),
                            "database": "disconnected",
                            "error": e.to_string()
                        }))
                    )
                }
            }
        }
        None => {
            (
                StatusCode::OK,
                Json(json!({
                    "status": "healthy",
                    "timestamp": chrono::Utc::now(),
                    "version": env!("CARGO_PKG_VERSION"),
                    "database": "not_configured"
                }))
            )
        }
    }
}