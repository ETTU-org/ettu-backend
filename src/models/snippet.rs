use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snippet {
    pub id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub code: String,
    pub language: String,
    pub is_public: bool,
    pub author_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSnippetRequest {
    pub title: String,
    pub description: Option<String>,
    pub code: String,
    pub language: String,
    pub is_public: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateSnippetRequest {
    pub title: Option<String>,
    pub description: Option<String>,
    pub code: Option<String>,
    pub language: Option<String>,
    pub is_public: Option<bool>,
}
