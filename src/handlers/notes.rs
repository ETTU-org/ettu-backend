use axum::{Router, routing::get};

pub fn routes() -> Router {
    Router::new()
        .route("/", get(list_notes))
}

async fn list_notes() -> &'static str {
    "List notes endpoint - TODO: Implement"
}
