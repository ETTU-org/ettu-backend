# Configuration Rust/Axum pour ETTU Backend

## Initialisation du projet

### 1. Créer le projet Rust

```bash
cargo new ettu-backend
cd ettu-backend
```

### 2. Configuration Cargo.toml

```toml
[package]
name = "ettu-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
# Framework web
axum = "0.7"
tower = "0.4"
tower-http = { version = "0.5", features = ["cors", "fs", "trace"] }
tokio = { version = "1.0", features = ["full"] }

# Base de données
sqlx = { version = "0.7", features = [
    "postgres", 
    "json", 
    "uuid", 
    "chrono", 
    "migrate",
    "runtime-tokio-rustls"
] }
redis = { version = "0.24", features = ["tokio-comp", "connection-manager"] }

# Authentification et sécurité
jsonwebtoken = "9.2"
bcrypt = "0.15"
uuid = { version = "1.7", features = ["v4", "serde"] }

# Sérialisation
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# Validation
validator = { version = "0.18", features = ["derive"] }

# Configuration
config = "0.14"
dotenv = "0.15"

# Logging et tracing
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Temps et dates
chrono = { version = "0.4", features = ["serde"] }

# HTTP client
reqwest = { version = "0.11", features = ["json"] }

# WebSocket
tokio-tungstenite = "0.21"

# Utilitaires
anyhow = "1.0"
thiserror = "1.0"

[dev-dependencies]
tokio-test = "0.4"
```

### 3. Structure du projet

```
src/
├── main.rs                 # Point d'entrée
├── lib.rs                  # Bibliothèque principale
├── config/                 # Configuration
│   ├── mod.rs
│   └── settings.rs
├── models/                 # Modèles de données
│   ├── mod.rs
│   ├── user.rs
│   ├── project.rs
│   ├── snippet.rs
│   └── task.rs
├── handlers/               # Handlers HTTP
│   ├── mod.rs
│   ├── auth.rs
│   ├── projects.rs
│   ├── snippets.rs
│   └── users.rs
├── middleware/             # Middleware personnalisés
│   ├── mod.rs
│   ├── auth.rs
│   ├── permissions.rs
│   └── rate_limit.rs
├── services/               # Logique métier
│   ├── mod.rs
│   ├── auth_service.rs
│   ├── project_service.rs
│   ├── snippet_service.rs
│   └── notification_service.rs
├── database/               # Accès base de données
│   ├── mod.rs
│   ├── connection.rs
│   ├── migrations.rs
│   └── repositories/
│       ├── mod.rs
│       ├── user_repository.rs
│       ├── project_repository.rs
│       └── snippet_repository.rs
├── utils/                  # Utilitaires
│   ├── mod.rs
│   ├── crypto.rs
│   ├── validation.rs
│   └── constants.rs
├── errors/                 # Gestion d'erreurs
│   ├── mod.rs
│   └── app_error.rs
├── websocket/              # WebSocket
│   ├── mod.rs
│   ├── connection.rs
│   └── handlers.rs
└── tests/                  # Tests
    ├── mod.rs
    ├── auth_tests.rs
    └── project_tests.rs
```

## Configuration de base

### 1. Configuration (config/settings.rs)

```rust
use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub redis: RedisSettings,
    pub server: ServerSettings,
    pub jwt: JwtSettings,
    pub app: AppSettings,
}

#[derive(Debug, Deserialize)]
pub struct DatabaseSettings {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
}

#[derive(Debug, Deserialize)]
pub struct RedisSettings {
    pub url: String,
    pub max_connections: u32,
}

#[derive(Debug, Deserialize)]
pub struct ServerSettings {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Deserialize)]
pub struct JwtSettings {
    pub secret: String,
    pub expiration: u64,
    pub refresh_expiration: u64,
}

#[derive(Debug, Deserialize)]
pub struct AppSettings {
    pub guest_session_duration: u64,
    pub max_guest_projects: u32,
    pub max_registered_projects: u32,
    pub enable_rate_limiting: bool,
}

impl Settings {
    pub fn new() -> Result<Self, ConfigError> {
        let config = Config::builder()
            .add_source(File::with_name("config/default"))
            .add_source(File::with_name("config/local").required(false))
            .add_source(Environment::with_prefix("ETTU"))
            .build()?;

        config.try_deserialize()
    }
}
```

### 2. Modèles de base (models/user.rs)

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: Uuid,
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub anonymous_id: Option<Uuid>,
    pub password_hash: Option<String>,
    pub user_type: UserType,
    pub session_expires_at: Option<DateTime<Utc>>,
    pub avatar_url: Option<String>,
    pub bio: Option<String>,
    pub is_active: bool,
    pub is_verified: bool,
    pub theme: String,
    pub language: String,
    pub timezone: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "user_type", rename_all = "lowercase")]
pub enum UserType {
    Guest,
    Registered,
    Migrated,
}

#[derive(Debug, Validate, Deserialize)]
pub struct CreateUserRequest {
    #[validate(email)]
    pub email: String,
    
    #[validate(length(min = 3, max = 50))]
    pub username: String,
    
    #[validate(length(min = 1, max = 100))]
    pub display_name: String,
    
    #[validate(length(min = 8))]
    pub password: String,
}

#[derive(Debug, Validate, Deserialize)]
pub struct LoginRequest {
    #[validate(email)]
    pub email: String,
    
    #[validate(length(min = 1))]
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub user_type: UserType,
    pub avatar_url: Option<String>,
    pub bio: Option<String>,
    pub is_verified: bool,
    pub theme: String,
    pub language: String,
    pub timezone: String,
    pub created_at: DateTime<Utc>,
}

impl From<User> for UserResponse {
    fn from(user: User) -> Self {
        UserResponse {
            id: user.id,
            email: user.email,
            username: user.username,
            display_name: user.display_name,
            user_type: user.user_type,
            avatar_url: user.avatar_url,
            bio: user.bio,
            is_verified: user.is_verified,
            theme: user.theme,
            language: user.language,
            timezone: user.timezone,
            created_at: user.created_at,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub user: UserResponse,
    pub token: String,
    pub refresh_token: Option<String>,
    pub expires_at: DateTime<Utc>,
}
```

### 3. Gestion des erreurs (errors/app_error.rs)

```rust
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("Redis error: {0}")]
    Redis(#[from] redis::RedisError),
    
    #[error("JWT error: {0}")]
    JWT(#[from] jsonwebtoken::errors::Error),
    
    #[error("Validation error: {0}")]
    Validation(#[from] validator::ValidationErrors),
    
    #[error("Unauthorized")]
    Unauthorized,
    
    #[error("Forbidden")]
    Forbidden,
    
    #[error("Not found")]
    NotFound,
    
    #[error("Bad request: {0}")]
    BadRequest(String),
    
    #[error("Internal server error: {0}")]
    InternalServerError(String),
    
    #[error("Rate limit exceeded")]
    RateLimitExceeded,
    
    #[error("Guest limit exceeded: {0}")]
    GuestLimitExceeded(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::Database(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Database error occurred".to_string(),
            ),
            AppError::Redis(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Cache error occurred".to_string(),
            ),
            AppError::JWT(_) => (
                StatusCode::UNAUTHORIZED,
                "Invalid token".to_string(),
            ),
            AppError::Validation(errors) => (
                StatusCode::BAD_REQUEST,
                format!("Validation error: {}", errors),
            ),
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "Unauthorized".to_string(),
            ),
            AppError::Forbidden => (
                StatusCode::FORBIDDEN,
                "Forbidden".to_string(),
            ),
            AppError::NotFound => (
                StatusCode::NOT_FOUND,
                "Not found".to_string(),
            ),
            AppError::BadRequest(msg) => (
                StatusCode::BAD_REQUEST,
                msg,
            ),
            AppError::InternalServerError(msg) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                msg,
            ),
            AppError::RateLimitExceeded => (
                StatusCode::TOO_MANY_REQUESTS,
                "Rate limit exceeded".to_string(),
            ),
            AppError::GuestLimitExceeded(msg) => (
                StatusCode::FORBIDDEN,
                msg,
            ),
        };

        let body = json!({
            "error": error_message,
            "status": status.as_u16()
        });

        (status, axum::Json(body)).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
```

### 4. Connexion base de données (database/connection.rs)

```rust
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::time::Duration;

use crate::config::Settings;
use crate::errors::AppResult;

pub async fn create_pool(settings: &Settings) -> AppResult<PgPool> {
    let pool = PgPoolOptions::new()
        .max_connections(settings.database.max_connections)
        .min_connections(settings.database.min_connections)
        .acquire_timeout(Duration::from_secs(8))
        .connect(&settings.database.url)
        .await?;

    Ok(pool)
}

pub async fn run_migrations(pool: &PgPool) -> AppResult<()> {
    sqlx::migrate!("./database/migrations")
        .run(pool)
        .await?;
    
    Ok(())
}
```

### 5. Middleware d'authentification (middleware/auth.rs)

```rust
use axum::{
    extract::Request,
    http::{header, StatusCode},
    middleware::Next,
    response::Response,
    Extension,
};
use jsonwebtoken::{decode, DecodingKey, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::errors::AppError;
use crate::models::user::UserType;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,
    pub user_type: UserType,
    pub session_id: Uuid,
    pub exp: usize,
    pub iat: usize,
}

#[derive(Debug, Clone)]
pub struct CurrentUser {
    pub id: Uuid,
    pub user_type: UserType,
    pub session_id: Uuid,
}

pub async fn auth_middleware(
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = extract_token(&req)?;
    let user = validate_token(&token).await?;
    
    req.extensions_mut().insert(user);
    
    Ok(next.run(req).await)
}

pub async fn optional_auth_middleware(
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    if let Ok(token) = extract_token(&req) {
        if let Ok(user) = validate_token(&token).await {
            req.extensions_mut().insert(user);
        }
    }
    
    Ok(next.run(req).await)
}

fn extract_token(req: &Request) -> Result<String, AppError> {
    let header = req
        .headers()
        .get(header::AUTHORIZATION)
        .ok_or(AppError::Unauthorized)?;

    let header_value = header.to_str().map_err(|_| AppError::Unauthorized)?;
    
    if !header_value.starts_with("Bearer ") {
        return Err(AppError::Unauthorized);
    }

    Ok(header_value.trim_start_matches("Bearer ").to_string())
}

async fn validate_token(token: &str) -> Result<CurrentUser, AppError> {
    let secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "dev_secret".to_string());
    
    let claims = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_ref()),
        &Validation::default(),
    )?;

    Ok(CurrentUser {
        id: claims.claims.sub,
        user_type: claims.claims.user_type,
        session_id: claims.claims.session_id,
    })
}
```

### 6. Main.rs complet

```rust
use axum::{
    extract::Extension,
    http::Method,
    routing::{get, post},
    Router,
};
use std::net::SocketAddr;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod config;
mod database;
mod errors;
mod handlers;
mod middleware;
mod models;
mod services;
mod utils;
mod websocket;

use config::Settings;
use database::connection::{create_pool, run_migrations};
use errors::AppResult;

#[tokio::main]
async fn main() -> AppResult<()> {
    // Initialiser le logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "ettu_backend=debug".into()),
        ))
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Charger la configuration
    let settings = Settings::new().expect("Failed to load configuration");

    // Créer le pool de connexions
    let pool = create_pool(&settings).await?;
    
    // Exécuter les migrations
    run_migrations(&pool).await?;

    // Créer le router
    let app = create_router(pool, settings.clone()).await?;

    // Démarrer le serveur
    let addr = SocketAddr::from(([0, 0, 0, 0], settings.server.port));
    tracing::info!("Server starting on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn create_router(pool: sqlx::PgPool, settings: Settings) -> AppResult<Router> {
    let cors = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers(Any)
        .allow_origin(Any);

    let app = Router::new()
        // Routes publiques
        .route("/", get(|| async { "ETTU Backend API" }))
        .route("/health", get(health_check))
        
        // Routes auth
        .route("/api/auth/register", post(handlers::auth::register))
        .route("/api/auth/login", post(handlers::auth::login))
        .route("/api/auth/guest", post(handlers::auth::create_guest))
        .route("/api/auth/migrate", post(handlers::auth::migrate_guest))
        .route("/api/auth/refresh", post(handlers::auth::refresh_token))
        
        // Routes projects (nécessitent auth)
        .route("/api/projects", get(handlers::projects::list_projects))
        .route("/api/projects", post(handlers::projects::create_project))
        .route("/api/projects/:id", get(handlers::projects::get_project))
        .route("/api/projects/:id", put(handlers::projects::update_project))
        .route("/api/projects/:id", delete(handlers::projects::delete_project))
        
        // Routes snippets publics
        .route("/api/snippets", get(handlers::snippets::list_snippets))
        .route("/api/snippets/:id", get(handlers::snippets::get_snippet))
        .route("/api/snippets", post(handlers::snippets::create_snippet))
        
        // WebSocket
        .route("/ws", get(websocket::handlers::websocket_handler))
        
        // Middleware global
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors)
                .layer(Extension(pool))
                .layer(Extension(settings))
        );

    Ok(app)
}

async fn health_check() -> &'static str {
    "OK"
}
```

## Configuration de développement

### 1. Fichier config/default.toml

```toml
[database]
url = "postgresql://ettu_user:ettu_password@localhost/ettu_dev"
max_connections = 10
min_connections = 2

[redis]
url = "redis://localhost:6379"
max_connections = 10

[server]
host = "0.0.0.0"
port = 3000

[jwt]
secret = "dev_secret_key_change_in_production"
expiration = 3600  # 1 heure
refresh_expiration = 2592000  # 30 jours

[app]
guest_session_duration = 2592000  # 30 jours
max_guest_projects = 5
max_registered_projects = 100
enable_rate_limiting = false
```

### 2. Variables d'environnement (.env)

```env
RUST_LOG=ettu_backend=debug,tower_http=debug
DATABASE_URL=postgresql://ettu_user:ettu_password@localhost/ettu_dev
REDIS_URL=redis://localhost:6379
JWT_SECRET=dev_secret_key_change_in_production
```

### 3. Docker Compose pour développement

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ettu_dev
      POSTGRES_USER: ettu_user
      POSTGRES_PASSWORD: ettu_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## Commandes utiles

### Développement

```bash
# Démarrer les services
docker-compose up -d

# Installer SQLx CLI
cargo install sqlx-cli

# Créer une migration
sqlx migrate add create_users_table

# Exécuter les migrations
sqlx migrate run

# Démarrer le serveur
cargo run

# Tests
cargo test

# Vérifier le code
cargo clippy
cargo fmt
```

### Production

```bash
# Build optimisé
cargo build --release

# Démarrer le serveur
RUST_LOG=info ./target/release/ettu-backend
```

Ce setup fournit une base solide pour développer le backend ETTU avec Rust et Axum, incluant l'authentification hybride, la gestion des erreurs, et une architecture modulaire.
