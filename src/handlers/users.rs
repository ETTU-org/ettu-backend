use axum::{Router, routing::get};

pub fn routes() -> Router {
    Router::new()
        .route("/me", get(get_current_user))
        .route("/profile", get(get_user_profile))
}

async fn get_current_user() -> &'static str {
    "Get current user endpoint - TODO: Implement"
}

async fn get_user_profile() -> &'static str {
    "Get user profile endpoint - TODO: Implement"
}
