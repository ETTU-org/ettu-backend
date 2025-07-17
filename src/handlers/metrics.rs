use axum::{response::Response, http::StatusCode};

pub async fn metrics() -> Response {
    // TODO: Implement Prometheus metrics
    Response::builder()
        .status(StatusCode::OK)
        .header("content-type", "text/plain")
        .body("# TODO: Implement metrics\n".into())
        .unwrap()
}
