use axum::{Router, routing::post};

pub fn routes() -> Router {
    Router::new()
        .route("/login", post(login))
        .route("/register", post(register))
        .route("/logout", post(logout))
        .route("/refresh", post(refresh_token))
        .route("/guest", post(create_guest))
        .route("/migrate", post(migrate_guest_to_user))
}

async fn login() -> &'static str {
    "Login endpoint - TODO: Implement"
}

async fn register() -> &'static str {
    "Register endpoint - TODO: Implement"
}

async fn logout() -> &'static str {
    "Logout endpoint - TODO: Implement"
}

async fn refresh_token() -> &'static str {
    "Refresh token endpoint - TODO: Implement"
}

async fn create_guest() -> &'static str {
    "Create guest endpoint - TODO: Implement"
}

async fn migrate_guest_to_user() -> &'static str {
    "Migrate guest to user endpoint - TODO: Implement"
}
