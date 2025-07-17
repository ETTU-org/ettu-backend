use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub message: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginationParams {
    pub page: Option<u64>,
    pub limit: Option<u64>,
    pub sort: Option<String>,
    pub order: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedResponse<T> {
    pub items: Vec<T>,
    pub total: u64,
    pub page: u64,
    pub limit: u64,
    pub total_pages: u64,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            message: None,
            error: None,
        }
    }
    
    pub fn success_with_message(data: T, message: String) -> Self {
        Self {
            success: true,
            data: Some(data),
            message: Some(message),
            error: None,
        }
    }
    
    pub fn error(error: String) -> Self {
        Self {
            success: false,
            data: None,
            message: None,
            error: Some(error),
        }
    }
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            page: Some(1),
            limit: Some(20),
            sort: None,
            order: Some("desc".to_string()),
        }
    }
}

impl PaginationParams {
    pub fn page(&self) -> u64 {
        self.page.unwrap_or(1)
    }
    
    pub fn limit(&self) -> u64 {
        self.limit.unwrap_or(20).min(100) // Max 100 items per page
    }
    
    pub fn offset(&self) -> u64 {
        (self.page() - 1) * self.limit()
    }
    
    pub fn sort(&self) -> &str {
        self.sort.as_deref().unwrap_or("created_at")
    }
    
    pub fn order(&self) -> &str {
        self.order.as_deref().unwrap_or("desc")
    }
}

impl<T> PaginatedResponse<T> {
    pub fn new(items: Vec<T>, total: u64, page: u64, limit: u64) -> Self {
        let total_pages = (total + limit - 1) / limit; // Ceiling division
        
        Self {
            items,
            total,
            page,
            limit,
            total_pages,
        }
    }
}
