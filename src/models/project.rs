use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProjectStatus {
    Active,
    Archived,
    Deleted,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProjectVisibility {
    Private,
    Public,
    Team,
}

#[derive(Debug, Clone, FromRow, Serialize, Deserialize)]
pub struct Project {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub icon: Option<String>,
    pub status: String,      // Will be converted to ProjectStatus
    pub visibility: String,  // Will be converted to ProjectVisibility
    pub owner_id: Uuid,
    pub settings: Option<serde_json::Value>,
    pub technologies: Option<serde_json::Value>,
    pub repository_url: Option<String>,
    pub live_url: Option<String>,
    pub version: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateProjectRequest {
    pub name: String,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub visibility: ProjectVisibility,
    pub technologies: Option<Vec<String>>,
    pub repository_url: Option<String>,
    pub live_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateProjectRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub visibility: Option<ProjectVisibility>,
    pub technologies: Option<Vec<String>>,
    pub repository_url: Option<String>,
    pub live_url: Option<String>,
    pub settings: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectResponse {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub icon: Option<String>,
    pub status: ProjectStatus,
    pub visibility: ProjectVisibility,
    pub owner_id: Uuid,
    pub settings: Option<serde_json::Value>,
    pub technologies: Option<Vec<String>>,
    pub repository_url: Option<String>,
    pub live_url: Option<String>,
    pub version: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub task_count: Option<i64>,
    pub note_count: Option<i64>,
}

#[derive(Debug, Clone, FromRow, Serialize, Deserialize)]
pub struct ProjectMember {
    pub id: Uuid,
    pub project_id: Uuid,
    pub user_id: Uuid,
    pub role: String,
    pub permissions: Option<serde_json::Value>,
    pub invited_by: Option<Uuid>,
    pub invited_at: Option<DateTime<Utc>>,
    pub joined_at: Option<DateTime<Utc>>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectInvitation {
    pub id: Uuid,
    pub project_id: Uuid,
    pub email: String,
    pub role: String,
    pub invited_by: Uuid,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

impl Project {
    pub fn status(&self) -> ProjectStatus {
        match self.status.as_str() {
            "active" => ProjectStatus::Active,
            "archived" => ProjectStatus::Archived,
            "deleted" => ProjectStatus::Deleted,
            _ => ProjectStatus::Active,
        }
    }
    
    pub fn visibility(&self) -> ProjectVisibility {
        match self.visibility.as_str() {
            "private" => ProjectVisibility::Private,
            "public" => ProjectVisibility::Public,
            "team" => ProjectVisibility::Team,
            _ => ProjectVisibility::Private,
        }
    }
    
    pub fn technologies(&self) -> Vec<String> {
        self.technologies
            .as_ref()
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str())
                    .map(|s| s.to_string())
                    .collect()
            })
            .unwrap_or_default()
    }
    
    pub fn into_response(self) -> ProjectResponse {
        let status = self.status();
        let visibility = self.visibility();
        let technologies = self.technologies();
        
        ProjectResponse {
            id: self.id,
            name: self.name,
            description: self.description,
            color: self.color,
            icon: self.icon,
            status,
            visibility,
            owner_id: self.owner_id,
            settings: self.settings,
            technologies: Some(technologies),
            repository_url: self.repository_url,
            live_url: self.live_url,
            version: self.version,
            created_at: self.created_at,
            updated_at: self.updated_at,
            task_count: None,
            note_count: None,
        }
    }
}

impl std::fmt::Display for ProjectStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ProjectStatus::Active => write!(f, "active"),
            ProjectStatus::Archived => write!(f, "archived"),
            ProjectStatus::Deleted => write!(f, "deleted"),
        }
    }
}

impl std::fmt::Display for ProjectVisibility {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ProjectVisibility::Private => write!(f, "private"),
            ProjectVisibility::Public => write!(f, "public"),
            ProjectVisibility::Team => write!(f, "team"),
        }
    }
}
