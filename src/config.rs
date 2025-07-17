use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub database_url: String,
    pub redis_url: String,
    pub jwt_secret: String,
    pub server: ServerConfig,
    pub cors: CorsConfig,
    pub email: EmailConfig,
    pub logging: LoggingConfig,
    pub features: FeatureConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub environment: Environment,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorsConfig {
    pub allowed_origins: Vec<String>,
    pub allowed_methods: Vec<String>,
    pub allowed_headers: Vec<String>,
    pub max_age: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmailConfig {
    pub smtp_host: String,
    pub smtp_port: u16,
    pub smtp_username: String,
    pub smtp_password: String,
    pub from_email: String,
    pub from_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggingConfig {
    pub level: String,
    pub format: String,
    pub file_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureConfig {
    pub guest_mode: bool,
    pub registration_enabled: bool,
    pub email_verification: bool,
    pub public_snippets: bool,
    pub rate_limiting: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Environment {
    Development,
    Testing,
    Staging,
    Production,
}

impl Default for Environment {
    fn default() -> Self {
        Environment::Development
    }
}

#[derive(Debug, Clone)]
pub enum ConfigError {
    ParseError(String),
    MissingEnv(String),
}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        dotenvy::dotenv().ok();
        
        let database_url = env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgresql://postgres:password@localhost:5432/ettu_db".to_string());
        
        let redis_url = env::var("REDIS_URL")
            .unwrap_or_else(|_| "redis://localhost:6379".to_string());
        
        let jwt_secret = env::var("JWT_SECRET")
            .unwrap_or_else(|_| "default-secret-key".to_string());
        
        let server = ServerConfig {
            host: env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string()),
            port: env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .map_err(|_| ConfigError::ParseError("Invalid port number".to_string()))?,
            environment: Environment::Development,
        };
        
        let cors = CorsConfig {
            allowed_origins: env::var("CORS_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000,http://localhost:5173".to_string())
                .split(',')
                .map(|s| s.trim().to_string())
                .collect(),
            allowed_methods: vec!["GET".to_string(), "POST".to_string(), "PUT".to_string(), "DELETE".to_string()],
            allowed_headers: vec!["Content-Type".to_string(), "Authorization".to_string()],
            max_age: 3600,
        };
        
        let email = EmailConfig {
            smtp_host: env::var("EMAIL_SMTP_HOST").unwrap_or_else(|_| "smtp.gmail.com".to_string()),
            smtp_port: env::var("EMAIL_SMTP_PORT")
                .unwrap_or_else(|_| "587".to_string())
                .parse()
                .unwrap_or(587),
            smtp_username: env::var("EMAIL_SMTP_USER").unwrap_or_default(),
            smtp_password: env::var("EMAIL_SMTP_PASSWORD").unwrap_or_default(),
            from_email: env::var("EMAIL_FROM").unwrap_or_else(|_| "noreply@ettu.dev".to_string()),
            from_name: env::var("EMAIL_FROM_NAME").unwrap_or_else(|_| "ETTU".to_string()),
        };
        
        let logging = LoggingConfig {
            level: env::var("LOG_LEVEL").unwrap_or_else(|_| "info".to_string()),
            format: env::var("LOG_FORMAT").unwrap_or_else(|_| "json".to_string()),
            file_path: env::var("LOG_FILE").ok(),
        };
        
        let features = FeatureConfig {
            guest_mode: env::var("GUEST_MODE").unwrap_or_else(|_| "true".to_string()).parse().unwrap_or(true),
            registration_enabled: env::var("REGISTRATION_ENABLED").unwrap_or_else(|_| "true".to_string()).parse().unwrap_or(true),
            email_verification: env::var("EMAIL_VERIFICATION").unwrap_or_else(|_| "false".to_string()).parse().unwrap_or(false),
            public_snippets: env::var("PUBLIC_SNIPPETS").unwrap_or_else(|_| "true".to_string()).parse().unwrap_or(true),
            rate_limiting: env::var("RATE_LIMITING").unwrap_or_else(|_| "true".to_string()).parse().unwrap_or(true),
        };
        
        Ok(Config {
            database_url,
            redis_url,
            jwt_secret,
            server,
            cors,
            email,
            logging,
            features,
        })
    }
    
    pub fn is_production(&self) -> bool {
        matches!(self.server.environment, Environment::Production)
    }
    
    pub fn is_development(&self) -> bool {
        matches!(self.server.environment, Environment::Development)
    }
    
    pub fn is_testing(&self) -> bool {
        matches!(self.server.environment, Environment::Testing)
    }
}

impl std::str::FromStr for Environment {
    type Err = String;
    
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "development" | "dev" => Ok(Environment::Development),
            "testing" | "test" => Ok(Environment::Testing),
            "staging" | "stage" => Ok(Environment::Staging),
            "production" | "prod" => Ok(Environment::Production),
            _ => Err(format!("Unknown environment: {}", s)),
        }
    }
}

impl std::fmt::Display for Environment {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Environment::Development => write!(f, "development"),
            Environment::Testing => write!(f, "testing"),
            Environment::Staging => write!(f, "staging"),
            Environment::Production => write!(f, "production"),
        }
    }
}
