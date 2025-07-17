use axum::{Router, routing::{get, post}};

pub fn routes() -> Router {
    Router::new()
        .route("/", get(list_projects).post(create_project))
        .route("/:id", get(get_project))
}

async fn list_projects() -> &'static str {
    "List projects endpoint - TODO: Implement"
}

async fn create_project() -> &'static str {
    "Create project endpoint - TODO: Implement"
}

async fn get_project() -> &'static str {
    "Get project endpoint - TODO: Implement"
}
