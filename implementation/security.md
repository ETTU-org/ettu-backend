# Guide de Sécurité ETTU Backend

## Vue d'ensemble

La sécurité est un aspect critique d'ETTU. Ce guide couvre les mesures de sécurité implémentées et les bonnes pratiques à suivre.

## Authentification et autorisation

### Système hybride sécurisé

#### Utilisateurs invités
- **Session temporaire** : Tokens JWT avec durée limitée (30 jours)
- **Pas de données sensibles** : Aucune information personnelle stockée
- **Limite d'utilisation** : Restrictions sur le nombre de projets/notes/snippets
- **Nettoyage automatique** : Suppression des données expirées

#### Utilisateurs enregistrés
- **Mot de passe fort** : bcrypt avec coût élevé (12+ rounds)
- **Tokens sécurisés** : JWT + refresh token avec rotation
- **Vérification email** : Confirmation d'email obligatoire
- **2FA optionnel** : Authentification à deux facteurs

### Implémentation JWT

```rust
use jsonwebtoken::{encode, decode, Header, Algorithm, EncodingKey, DecodingKey, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{Duration, Utc};

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,           // User ID
    pub user_type: String,   // guest, registered, migrated
    pub session_id: Uuid,    // Session ID pour révocation
    pub exp: usize,          // Expiration
    pub iat: usize,          // Issued at
    pub iss: String,         // Issuer
    pub aud: String,         // Audience
}

pub struct JwtService {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    validation: Validation,
}

impl JwtService {
    pub fn new(secret: &str) -> Self {
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&["ettu-backend"]);
        validation.set_audience(&["ettu-frontend"]);
        
        Self {
            encoding_key: EncodingKey::from_secret(secret.as_ref()),
            decoding_key: DecodingKey::from_secret(secret.as_ref()),
            validation,
        }
    }

    pub fn generate_token(&self, user_id: Uuid, user_type: &str, session_id: Uuid) -> Result<String, jsonwebtoken::errors::Error> {
        let now = Utc::now();
        let expiration = now + Duration::hours(1);
        
        let claims = Claims {
            sub: user_id,
            user_type: user_type.to_string(),
            session_id,
            exp: expiration.timestamp() as usize,
            iat: now.timestamp() as usize,
            iss: "ettu-backend".to_string(),
            aud: "ettu-frontend".to_string(),
        };

        encode(&Header::default(), &claims, &self.encoding_key)
    }

    pub fn validate_token(&self, token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
        let token_data = decode::<Claims>(token, &self.decoding_key, &self.validation)?;
        Ok(token_data.claims)
    }
}
```

### Gestion des mots de passe

```rust
use bcrypt::{hash, verify, DEFAULT_COST};
use validator::Validate;

#[derive(Debug, Validate)]
pub struct PasswordPolicy {
    #[validate(length(min = 8, max = 128))]
    pub password: String,
}

pub struct PasswordService;

impl PasswordService {
    pub fn hash_password(password: &str) -> Result<String, bcrypt::BcryptError> {
        // Utiliser un coût élevé pour la sécurité
        hash(password, 12)
    }

    pub fn verify_password(password: &str, hash: &str) -> Result<bool, bcrypt::BcryptError> {
        verify(password, hash)
    }

    pub fn validate_password_strength(password: &str) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        if password.len() < 8 {
            errors.push("Le mot de passe doit contenir au moins 8 caractères".to_string());
        }

        if !password.chars().any(|c| c.is_uppercase()) {
            errors.push("Le mot de passe doit contenir au moins une majuscule".to_string());
        }

        if !password.chars().any(|c| c.is_lowercase()) {
            errors.push("Le mot de passe doit contenir au moins une minuscule".to_string());
        }

        if !password.chars().any(|c| c.is_numeric()) {
            errors.push("Le mot de passe doit contenir au moins un chiffre".to_string());
        }

        if !password.chars().any(|c| "!@#$%^&*()_+-=[]{}|;:,.<>?".contains(c)) {
            errors.push("Le mot de passe doit contenir au moins un caractère spécial".to_string());
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}
```

## Protection contre les attaques

### CSRF Protection

```rust
use axum::{
    extract::Request,
    middleware::Next,
    response::Response,
    http::header,
};
use uuid::Uuid;

pub async fn csrf_middleware(
    req: Request,
    next: Next,
) -> Result<Response, AppError> {
    // Vérifier l'origine pour les requêtes POST/PUT/DELETE
    if matches!(req.method(), &Method::POST | &Method::PUT | &Method::DELETE) {
        let origin = req
            .headers()
            .get(header::ORIGIN)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("");

        let allowed_origins = vec![
            "http://localhost:3000",
            "https://ettu.dev",
            "https://app.ettu.dev",
        ];

        if !allowed_origins.contains(&origin) {
            return Err(AppError::Forbidden);
        }
    }

    Ok(next.run(req).await)
}
```

### Rate Limiting

```rust
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc, Duration};

pub struct RateLimiter {
    requests: Arc<RwLock<HashMap<String, Vec<DateTime<Utc>>>>>,
    max_requests: usize,
    window_duration: Duration,
}

impl RateLimiter {
    pub fn new(max_requests: usize, window_minutes: i64) -> Self {
        Self {
            requests: Arc::new(RwLock::new(HashMap::new())),
            max_requests,
            window_duration: Duration::minutes(window_minutes),
        }
    }

    pub async fn check_rate_limit(&self, key: &str) -> bool {
        let now = Utc::now();
        let window_start = now - self.window_duration;

        let mut requests = self.requests.write().await;
        let user_requests = requests.entry(key.to_string()).or_insert_with(Vec::new);

        // Nettoyer les anciennes requêtes
        user_requests.retain(|&time| time > window_start);

        if user_requests.len() >= self.max_requests {
            return false;
        }

        user_requests.push(now);
        true
    }
}

pub async fn rate_limit_middleware(
    req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let ip = req
        .headers()
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("unknown");

    let limiter = RateLimiter::new(100, 60); // 100 requêtes par heure
    
    if !limiter.check_rate_limit(ip).await {
        return Err(AppError::RateLimitExceeded);
    }

    Ok(next.run(req).await)
}
```

### SQL Injection Protection

```rust
use sqlx::{PgPool, Row};
use uuid::Uuid;

pub struct UserRepository {
    pool: PgPool,
}

impl UserRepository {
    // ✅ Sécurisé - Utilise des requêtes paramétrées
    pub async fn find_by_email(&self, email: &str) -> Result<Option<User>, sqlx::Error> {
        let user = sqlx::query_as!(
            User,
            "SELECT * FROM users WHERE email = $1",
            email
        )
        .fetch_optional(&self.pool)
        .await?;

        Ok(user)
    }

    // ✅ Sécurisé - Utilise des requêtes préparées
    pub async fn search_projects(&self, user_id: Uuid, search_term: &str) -> Result<Vec<Project>, sqlx::Error> {
        let projects = sqlx::query_as!(
            Project,
            r#"
            SELECT * FROM projects 
            WHERE owner_id = $1 
            AND (name ILIKE $2 OR description ILIKE $2)
            ORDER BY created_at DESC
            "#,
            user_id,
            format!("%{}%", search_term)
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(projects)
    }
}
```

### XSS Protection

```rust
use ammonia::clean;
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct CreateNoteRequest {
    pub title: String,
    pub content: String,
    pub tags: Vec<String>,
}

impl CreateNoteRequest {
    pub fn sanitize(self) -> SanitizedCreateNoteRequest {
        SanitizedCreateNoteRequest {
            title: clean(&self.title),
            content: clean(&self.content),
            tags: self.tags.into_iter().map(|tag| clean(&tag)).collect(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct SanitizedCreateNoteRequest {
    pub title: String,
    pub content: String,
    pub tags: Vec<String>,
}
```

## Audit et monitoring

### Logging de sécurité

```rust
use tracing::{info, warn, error};
use serde_json::json;

pub struct SecurityLogger;

impl SecurityLogger {
    pub fn log_login_attempt(email: &str, ip: &str, success: bool) {
        if success {
            info!(
                target: "security",
                event = "login_success",
                email = email,
                ip = ip,
                "User login successful"
            );
        } else {
            warn!(
                target: "security",
                event = "login_failure",
                email = email,
                ip = ip,
                "User login failed"
            );
        }
    }

    pub fn log_permission_denied(user_id: Uuid, action: &str, resource: &str) {
        warn!(
            target: "security",
            event = "permission_denied",
            user_id = %user_id,
            action = action,
            resource = resource,
            "Permission denied"
        );
    }

    pub fn log_suspicious_activity(user_id: Uuid, activity: &str, details: serde_json::Value) {
        error!(
            target: "security",
            event = "suspicious_activity",
            user_id = %user_id,
            activity = activity,
            details = %details,
            "Suspicious activity detected"
        );
    }
}
```

### Détection d'anomalies

```rust
use std::collections::HashMap;
use chrono::{DateTime, Utc};

pub struct AnomalyDetector {
    user_actions: HashMap<Uuid, Vec<UserAction>>,
}

#[derive(Debug, Clone)]
pub struct UserAction {
    pub action_type: String,
    pub timestamp: DateTime<Utc>,
    pub ip_address: String,
    pub user_agent: String,
}

impl AnomalyDetector {
    pub fn new() -> Self {
        Self {
            user_actions: HashMap::new(),
        }
    }

    pub fn record_action(&mut self, user_id: Uuid, action: UserAction) {
        self.user_actions
            .entry(user_id)
            .or_insert_with(Vec::new)
            .push(action);
    }

    pub fn detect_anomalies(&self, user_id: Uuid) -> Vec<String> {
        let mut anomalies = Vec::new();

        if let Some(actions) = self.user_actions.get(&user_id) {
            // Détecter les connexions depuis plusieurs IP
            let unique_ips: std::collections::HashSet<_> = 
                actions.iter().map(|a| &a.ip_address).collect();
            
            if unique_ips.len() > 5 {
                anomalies.push("Multiple IP addresses detected".to_string());
            }

            // Détecter l'activité suspecte
            let recent_actions: Vec<_> = actions
                .iter()
                .filter(|a| a.timestamp > Utc::now() - chrono::Duration::hours(1))
                .collect();

            if recent_actions.len() > 100 {
                anomalies.push("High activity volume detected".to_string());
            }
        }

        anomalies
    }
}
```

## Configuration sécurisée

### Variables d'environnement

```bash
# Secrets (ne jamais commiter)
JWT_SECRET=super_secure_random_string_256_bits
DATABASE_URL=postgresql://user:password@localhost/db
REDIS_URL=redis://localhost:6379

# Configuration de sécurité
BCRYPT_COST=12
JWT_EXPIRATION=3600
REFRESH_TOKEN_EXPIRATION=2592000
SESSION_TIMEOUT=1800

# Rate limiting
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=3600

# CORS
ALLOWED_ORIGINS=https://ettu.dev,https://app.ettu.dev
```

### Headers de sécurité

```rust
use axum::{
    extract::Request,
    middleware::Next,
    response::Response,
    http::header,
};

pub async fn security_headers_middleware(
    req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let mut response = next.run(req).await;

    let headers = response.headers_mut();
    
    // Prévenir le clickjacking
    headers.insert(
        header::HeaderName::from_static("x-frame-options"),
        header::HeaderValue::from_static("DENY"),
    );

    // Prévenir le sniffing MIME
    headers.insert(
        header::HeaderName::from_static("x-content-type-options"),
        header::HeaderValue::from_static("nosniff"),
    );

    // Protection XSS
    headers.insert(
        header::HeaderName::from_static("x-xss-protection"),
        header::HeaderValue::from_static("1; mode=block"),
    );

    // HSTS
    headers.insert(
        header::HeaderName::from_static("strict-transport-security"),
        header::HeaderValue::from_static("max-age=31536000; includeSubDomains"),
    );

    // CSP
    headers.insert(
        header::HeaderName::from_static("content-security-policy"),
        header::HeaderValue::from_static(
            "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
        ),
    );

    Ok(response)
}
```

## Sauvegarde et récupération

### Chiffrement des sauvegardes

```rust
use aes_gcm::{Aes256Gcm, Key, Nonce};
use aes_gcm::aead::{Aead, NewAead};
use rand::Rng;

pub struct BackupEncryption {
    cipher: Aes256Gcm,
}

impl BackupEncryption {
    pub fn new(key: &[u8; 32]) -> Self {
        let key = Key::from_slice(key);
        let cipher = Aes256Gcm::new(key);
        
        Self { cipher }
    }

    pub fn encrypt_backup(&self, data: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let mut rng = rand::thread_rng();
        let nonce_bytes: [u8; 12] = rng.gen();
        let nonce = Nonce::from_slice(&nonce_bytes);
        
        let ciphertext = self.cipher.encrypt(nonce, data)?;
        
        // Combiner nonce + ciphertext
        let mut result = nonce_bytes.to_vec();
        result.extend(ciphertext);
        
        Ok(result)
    }

    pub fn decrypt_backup(&self, encrypted_data: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        if encrypted_data.len() < 12 {
            return Err("Invalid encrypted data".into());
        }

        let (nonce_bytes, ciphertext) = encrypted_data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);
        
        let plaintext = self.cipher.decrypt(nonce, ciphertext)?;
        
        Ok(plaintext)
    }
}
```

## Tests de sécurité

### Tests automatisés

```rust
#[cfg(test)]
mod security_tests {
    use super::*;

    #[tokio::test]
    async fn test_password_hashing() {
        let password = "test_password123!";
        let hash = PasswordService::hash_password(password).unwrap();
        
        assert!(PasswordService::verify_password(password, &hash).unwrap());
        assert!(!PasswordService::verify_password("wrong_password", &hash).unwrap());
    }

    #[tokio::test]
    async fn test_jwt_token_validation() {
        let jwt_service = JwtService::new("test_secret");
        let user_id = Uuid::new_v4();
        let session_id = Uuid::new_v4();
        
        let token = jwt_service.generate_token(user_id, "registered", session_id).unwrap();
        let claims = jwt_service.validate_token(&token).unwrap();
        
        assert_eq!(claims.sub, user_id);
        assert_eq!(claims.user_type, "registered");
        assert_eq!(claims.session_id, session_id);
    }

    #[tokio::test]
    async fn test_rate_limiting() {
        let limiter = RateLimiter::new(5, 60);
        
        // Première série de requêtes
        for _ in 0..5 {
            assert!(limiter.check_rate_limit("test_user").await);
        }
        
        // Sixième requête devrait être bloquée
        assert!(!limiter.check_rate_limit("test_user").await);
    }

    #[tokio::test]
    async fn test_sql_injection_prevention() {
        // Test que les requêtes paramétrées préviennent l'injection SQL
        let malicious_input = "'; DROP TABLE users; --";
        
        // Cette requête devrait être sécurisée
        let result = sqlx::query!(
            "SELECT * FROM users WHERE email = $1",
            malicious_input
        );
        
        // Le résultat devrait être vide, pas une erreur SQL
        assert!(result.is_ok());
    }
}
```

## Checklist de sécurité

### Développement
- [ ] Utiliser des requêtes paramétrées
- [ ] Valider toutes les entrées utilisateur
- [ ] Nettoyer les données avant stockage
- [ ] Utiliser HTTPS en production
- [ ] Implémenter le rate limiting
- [ ] Logger les événements de sécurité
- [ ] Chiffrer les données sensibles
- [ ] Utiliser des secrets sécurisés

### Déploiement
- [ ] Configuration des headers de sécurité
- [ ] Mise à jour régulière des dépendances
- [ ] Monitoring de sécurité actif
- [ ] Sauvegardes chiffrées
- [ ] Tests de pénétration
- [ ] Plan de réponse aux incidents
- [ ] Audit régulier du code
- [ ] Formation de l'équipe

### Monitoring
- [ ] Logs de sécurité centralisés
- [ ] Alertes automatiques
- [ ] Détection d'anomalies
- [ ] Métriques de sécurité
- [ ] Rapports réguliers
- [ ] Tests de vulnérabilité
- [ ] Veille sécurité
- [ ] Mise à jour des correctifs

Cette configuration fournit une base solide pour la sécurité du backend ETTU, avec des mesures préventives, détectives et correctives.
