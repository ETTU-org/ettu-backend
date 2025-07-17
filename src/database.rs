use sqlx::{PgPool, Row};
use std::time::Duration;
use tracing::{error, info};

#[derive(Clone)]
pub struct Database {
    pool: PgPool,
}

impl Database {
    pub async fn connect(database_url: &str) -> Result<Self, sqlx::Error> {
        info!("Connecting to database...");
        
        let pool = sqlx::postgres::PgPoolOptions::new()
            .max_connections(20)
            .min_connections(5)
            .acquire_timeout(Duration::from_secs(30))
            .idle_timeout(Duration::from_secs(300))
            .max_lifetime(Duration::from_secs(1800))
            .connect(database_url)
            .await?;
        
        info!("Database connection established");
        
        Ok(Database { pool })
    }
    
    pub async fn migrate(&self) -> Result<(), sqlx::Error> {
        info!("Running database migrations...");
        
        sqlx::migrate!("./migrations")
            .run(&self.pool)
            .await?;
        
        info!("Database migrations completed");
        Ok(())
    }
    
    pub async fn health_check(&self) -> Result<(), sqlx::Error> {
        let row = sqlx::query("SELECT 1 as health")
            .fetch_one(&self.pool)
            .await?;
        
        let health: i32 = row.try_get("health")?;
        
        if health == 1 {
            Ok(())
        } else {
            Err(sqlx::Error::RowNotFound)
        }
    }
    
    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
    
    pub async fn close(&self) {
        self.pool.close().await;
    }
}

// Database utilities
pub mod utils {
    use super::*;
    use uuid::Uuid;
    
    pub fn generate_id() -> Uuid {
        Uuid::new_v4()
    }
    
    pub fn parse_uuid(id: &str) -> Result<Uuid, uuid::Error> {
        Uuid::parse_str(id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_database_connection() {
        // This test requires a test database
        // Skip if DATABASE_URL is not set
        if std::env::var("DATABASE_URL").is_err() {
            return;
        }
        
        let database_url = std::env::var("DATABASE_URL").unwrap();
        let db = Database::connect(&database_url).await;
        
        assert!(db.is_ok());
        
        if let Ok(db) = db {
            let health = db.health_check().await;
            assert!(health.is_ok());
        }
    }
}
