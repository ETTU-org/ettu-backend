use axum::{Router, routing::get};

pub fn routes() -> Router {
    Router::new()
        .route("/", get(list_snippets))
}

async fn list_snippets() -> &'static str {
    "List snippets endpoint - TODO: Implement"
}
