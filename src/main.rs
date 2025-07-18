use std::env;
use std::net::SocketAddr;
use std::sync::Arc;

use axum::{
    extract::Extension,
    http::Method,
    routing::{get, post},
    Router,
};
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::{info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod config;
mod database;
mod handlers;
mod middleware;
mod models;
mod services;
mod utils;

use config::Config;
use database::Database;

#[derive(Clone)]
pub struct AppState {
    pub db: Option<Database>,
    pub config: Config,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "ettu_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("Starting ETTU Backend Server");

    // Load configuration
    let config = Config::from_env().expect("Failed to load configuration");
    info!("Configuration loaded successfully");

    // Initialize database connection
    let db = match Database::connect(&config.database_url).await {
        Ok(db) => {
            info!("✅ Database connected successfully");
            Some(db)
        }
        Err(e) => {
            warn!("⚠️  Database connection failed: {}. Running in database-less mode.", e);
            None
        }
    };

    // Run migrations if database is available
    if let Some(ref database) = db {
        match database.migrate().await {
            Ok(_) => info!("✅ Database migrations completed successfully"),
            Err(e) => {
                warn!("⚠️  Migration warning: {}. This may be normal if migrations are already applied.", e);
                info!("Continuing with current database state...");
            }
        }
    }

    // Application state
    let app_state = AppState {
        db: db.clone(),
        config: config.clone(),
    };

    // Build application routes
    let app = build_router(Arc::new(app_state));

    // Start server
    let addr = SocketAddr::from(([0, 0, 0, 0], config.server.port));
    info!("Server starting on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    
    axum::serve(listener, app)
        .await
        .expect("Failed to start server");

    Ok(())
}

fn build_router(state: Arc<AppState>) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::PATCH,
        ])
        .allow_headers(Any);
    
    Router::new()
        // Health check
        .route("/health", get(handlers::health::health_check))
        .route("/metrics", get(handlers::metrics::metrics))
        // API routes
        .nest("/api/v1", api_routes())
        .with_state(state)
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors)
        )
}

fn api_routes() -> Router<Arc<AppState>> {
    Router::new()
        .route("/status", get(|| async { "API is running" }))
        // Pour l'instant, on ajoute juste une route de test
        // On ajoutera les autres routes plus tard
}
