use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum UserType {
    Guest,
    Registered,
    Migrated,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum UserRole {
    User,
    Reviewer,
    Moderator,
    Admin,
    Restricted,
}

#[derive(Debug, Clone, FromRow, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub password_hash: Option<String>,
    pub user_type: String, // Will be converted to UserType
    pub role: String,      // Will be converted to UserRole
    pub is_active: bool,
    pub is_verified: bool,
    pub profile_picture: Option<String>,
    pub bio: Option<String>,
    pub location: Option<String>,
    pub website: Option<String>,
    pub theme: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
    pub settings: Option<serde_json::Value>,
    pub last_login: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateUserRequest {
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub password: Option<String>,
    pub user_type: UserType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateUserRequest {
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub profile_picture: Option<String>,
    pub bio: Option<String>,
    pub location: Option<String>,
    pub website: Option<String>,
    pub theme: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
    pub settings: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: Option<String>,
    pub user_type: UserType,
    pub role: UserRole,
    pub is_active: bool,
    pub is_verified: bool,
    pub profile_picture: Option<String>,
    pub bio: Option<String>,
    pub location: Option<String>,
    pub website: Option<String>,
    pub theme: Option<String>,
    pub language: Option<String>,
    pub timezone: Option<String>,
    pub last_login: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow, Serialize, Deserialize)]
pub struct UserSession {
    pub id: Uuid,
    pub user_id: Uuid,
    pub token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub last_used: DateTime<Utc>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginRequest {
    pub email: Option<String>,
    pub username: Option<String>,
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginResponse {
    pub user: UserResponse,
    pub token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub username: String,
    pub display_name: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GuestToUserMigrationRequest {
    pub guest_id: Uuid,
    pub email: String,
    pub username: String,
    pub display_name: String,
    pub password: String,
}

impl User {
    pub fn user_type(&self) -> UserType {
        match self.user_type.as_str() {
            "guest" => UserType::Guest,
            "registered" => UserType::Registered,
            "migrated" => UserType::Migrated,
            _ => UserType::Guest,
        }
    }
    
    pub fn role(&self) -> UserRole {
        match self.role.as_str() {
            "user" => UserRole::User,
            "reviewer" => UserRole::Reviewer,
            "moderator" => UserRole::Moderator,
            "admin" => UserRole::Admin,
            "restricted" => UserRole::Restricted,
            _ => UserRole::User,
        }
    }
    
    pub fn is_guest(&self) -> bool {
        matches!(self.user_type(), UserType::Guest)
    }
    
    pub fn is_registered(&self) -> bool {
        matches!(self.user_type(), UserType::Registered | UserType::Migrated)
    }
    
    pub fn can_login(&self) -> bool {
        self.is_registered() && self.password_hash.is_some()
    }
    
    pub fn into_response(self) -> UserResponse {
        let user_type = self.user_type();
        let role = self.role();
        
        UserResponse {
            id: self.id,
            email: self.email,
            username: self.username,
            display_name: self.display_name,
            user_type,
            role,
            is_active: self.is_active,
            is_verified: self.is_verified,
            profile_picture: self.profile_picture,
            bio: self.bio,
            location: self.location,
            website: self.website,
            theme: self.theme,
            language: self.language,
            timezone: self.timezone,
            last_login: self.last_login,
            created_at: self.created_at,
            updated_at: self.updated_at,
        }
    }
}

impl std::fmt::Display for UserType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            UserType::Guest => write!(f, "guest"),
            UserType::Registered => write!(f, "registered"),
            UserType::Migrated => write!(f, "migrated"),
        }
    }
}

impl std::fmt::Display for UserRole {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            UserRole::User => write!(f, "user"),
            UserRole::Reviewer => write!(f, "reviewer"),
            UserRole::Moderator => write!(f, "moderator"),
            UserRole::Admin => write!(f, "admin"),
            UserRole::Restricted => write!(f, "restricted"),
        }
    }
}
