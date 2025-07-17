use axum::{Router, routing::get};

pub fn routes() -> Router {
    Router::new()
        .route("/snippets", get(list_public_snippets))
}

async fn list_public_snippets() -> &'static str {
    "List public snippets endpoint - TODO: Implement"
}
