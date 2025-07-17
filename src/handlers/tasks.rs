use axum::{Router, routing::get};

pub fn routes() -> Router {
    Router::new()
        .route("/", get(list_tasks))
}

async fn list_tasks() -> &'static str {
    "List tasks endpoint - TODO: Implement"
}
