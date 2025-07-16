# Contributing to ETTU Backend

Merci de votre intérêt pour contribuer au backend ETTU ! Ce guide vous aidera à bien démarrer.

## 🚀 Démarrage rapide

### 1. Fork et clone

```bash
git clone https://github.com/votre-username/ettu-backend.git
cd ettu-backend
git remote add upstream https://github.com/ETTU-org/ettu-backend.git
```

### 2. Configuration de l'environnement

```bash
# Installer Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Installer les outils
cargo install sqlx-cli
cargo install cargo-watch
cargo install cargo-tarpaulin

# Copier la configuration
cp .env.example .env
```

### 3. Démarrer les services

```bash
# Avec Docker
docker-compose up -d postgres redis

# Ou installer localement
# PostgreSQL et Redis selon votre OS
```

### 4. Exécuter les migrations

```bash
sqlx database create
sqlx migrate run
```

### 5. Lancer les tests

```bash
cargo test
```

## 📋 Workflow de contribution

### 1. Créer une branche

```bash
git checkout -b feature/ma-nouvelle-fonctionnalite
# ou
git checkout -b fix/correction-bug
```

### 2. Développer

- Écrire le code
- Ajouter des tests
- Mettre à jour la documentation
- Respecter les conventions de code

### 3. Tester

```bash
# Tests unitaires
cargo test

# Tests d'intégration
cargo test --features integration

# Vérifier le style
cargo fmt --check
cargo clippy -- -D warnings

# Coverage
cargo tarpaulin --out html
```

### 4. Commit

```bash
git add .
git commit -m "feat: ajouter nouvelle fonctionnalité"
```

### 5. Pousser et créer une PR

```bash
git push origin feature/ma-nouvelle-fonctionnalite
```

Puis créer une Pull Request sur GitHub.

## 🎯 Types de contributions

### 🐛 Correction de bugs

- Reproduire le bug
- Créer un test qui échoue
- Implémenter la correction
- Vérifier que le test passe

### ✨ Nouvelles fonctionnalités

- Discuter de la fonctionnalité dans une issue
- Créer un design doc si nécessaire
- Implémenter avec des tests
- Mettre à jour la documentation

### 📚 Documentation

- Améliorer les commentaires de code
- Mettre à jour le README
- Ajouter des exemples
- Corriger les typos

### 🔧 Améliorations techniques

- Optimisations de performance
- Refactoring de code
- Amélioration de la structure
- Mise à jour des dépendances

## 📏 Standards de code

### Style Rust

```rust
// Utiliser le formatter standard
cargo fmt

// Respecter les conventions
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

// Documenter les fonctions publiques
/// Crée un nouvel utilisateur avec les données fournies
pub async fn create_user(data: CreateUserData) -> Result<User, Error> {
    // ...
}
```

### Conventions de nommage

- **Fonctions** : `snake_case`
- **Types** : `PascalCase`
- **Constantes** : `UPPER_SNAKE_CASE`
- **Modules** : `snake_case`
- **Endpoints** : `/api/resource-name`

### Structure des handlers

```rust
pub async fn create_project(
    Extension(current_user): Extension<CurrentUser>,
    Json(payload): Json<CreateProjectRequest>,
) -> Result<Json<ProjectResponse>, AppError> {
    // 1. Valider les données
    payload.validate()?;
    
    // 2. Vérifier les permissions
    if !user_has_permission(&current_user, "create_projects").await? {
        return Err(AppError::Forbidden);
    }
    
    // 3. Logique métier
    let project = create_project_service(&current_user, payload).await?;
    
    // 4. Retourner la réponse
    Ok(Json(project.into()))
}
```

## 🧪 Tests

### Tests unitaires

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_create_user_success() {
        let user_data = CreateUserData {
            email: "test@example.com".to_string(),
            username: "testuser".to_string(),
            password: "securepassword123".to_string(),
        };
        
        let result = create_user(user_data).await;
        assert!(result.is_ok());
    }
    
    #[tokio::test]
    async fn test_create_user_duplicate_email() {
        // Test de gestion d'erreur
    }
}
```

### Tests d'intégration

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;
    
    #[tokio::test]
    async fn test_full_auth_flow() {
        let app = create_test_app().await;
        
        // Test du flow complet
        let response = app
            .post("/api/auth/register")
            .json(&register_data)
            .send()
            .await;
            
        assert_eq!(response.status(), 201);
    }
}
```

## 🔍 Debugging

### Logs

```rust
use tracing::{info, warn, error, debug};

// Utiliser les logs structurés
info!(
    user_id = %user.id,
    action = "create_project",
    "User created a new project"
);

// Éviter les logs sensibles
debug!(user_email = %user.email, "Processing request"); // ❌
debug!(user_id = %user.id, "Processing request"); // ✅
```

### Environnement de développement

```bash
# Logs détaillés
RUST_LOG=debug cargo run

# Avec watch pour rechargement auto
cargo watch -x run

# Profiling
cargo run --release --features profiling
```

## 📊 Performance

### Benchmarks

```rust
#[cfg(test)]
mod benches {
    use super::*;
    use criterion::{black_box, criterion_group, criterion_main, Criterion};
    
    fn bench_create_user(c: &mut Criterion) {
        c.bench_function("create_user", |b| {
            b.iter(|| create_user(black_box(test_data())))
        });
    }
}
```

### Optimisations

- Utiliser `async/await` correctement
- Éviter les clones inutiles
- Utiliser des références quand possible
- Profiler avec `cargo flamegraph`

## 🔒 Sécurité

### Vérifications avant PR

- [ ] Pas de secrets hardcodés
- [ ] Validation des entrées utilisateur
- [ ] Gestion des erreurs appropriée
- [ ] Tests de sécurité ajoutés
- [ ] Documentation mise à jour

### Bonnes pratiques

```rust
// Validation des entrées
#[derive(Validate, Deserialize)]
pub struct CreateUserRequest {
    #[validate(email)]
    pub email: String,
    
    #[validate(length(min = 3, max = 50))]
    pub username: String,
    
    #[validate(length(min = 8))]
    pub password: String,
}

// Gestion des erreurs
pub enum AppError {
    Validation(ValidationErrors),
    Database(sqlx::Error),
    Unauthorized,
    // ...
}
```

## 📝 Documentation

### Commentaires de code

```rust
/// Crée un nouveau projet pour l'utilisateur spécifié
/// 
/// # Arguments
/// * `user` - L'utilisateur propriétaire du projet
/// * `data` - Les données du projet à créer
/// 
/// # Returns
/// * `Result<Project, AppError>` - Le projet créé ou une erreur
/// 
/// # Errors
/// * `AppError::Validation` - Si les données sont invalides
/// * `AppError::Database` - Si l'insertion échoue
pub async fn create_project(
    user: &User,
    data: CreateProjectData,
) -> Result<Project, AppError> {
    // ...
}
```

### Documentation API

- Utiliser OpenAPI/Swagger
- Documenter tous les endpoints
- Inclure des exemples
- Spécifier les codes d'erreur

## 🤝 Code Review

### Checklist pour les reviewers

- [ ] Le code respecte les conventions
- [ ] Les tests passent
- [ ] La documentation est à jour
- [ ] Pas de régression de performance
- [ ] Sécurité vérifiée
- [ ] Pas de breaking changes non documentés

### Checklist pour les auteurs

- [ ] J'ai testé localement
- [ ] J'ai ajouté des tests
- [ ] J'ai mis à jour la documentation
- [ ] J'ai vérifié la sécurité
- [ ] J'ai vérifié les performances
- [ ] Mon code est formaté (`cargo fmt`)
- [ ] Pas de warnings (`cargo clippy`)

## 🆘 Obtenir de l'aide

- 💬 [Discussions GitHub](https://github.com/ETTU-org/ettu-backend/discussions)
- 🐛 [Issues](https://github.com/ETTU-org/ettu-backend/issues)
- 📧 Email: dev@ettu.dev
- 💬 Discord: [Rejoindre le serveur](https://discord.gg/ettu)

## 📚 Ressources

### Rust

- [The Rust Book](https://doc.rust-lang.org/book/)
- [Async Book](https://rust-lang.github.io/async-book/)
- [Axum Documentation](https://docs.rs/axum/)

### Base de données

- [SQLx Book](https://github.com/launchbadge/sqlx/blob/main/README.md)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

### Architecture

- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)

Merci de contribuer à ETTU ! 🚀
