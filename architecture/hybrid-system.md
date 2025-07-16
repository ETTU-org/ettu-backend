# ETTU - Architecture Hybride Invité/Compte

## 🎯 Philosophie du Système Hybride

L'objectif est de permettre une **utilisation immédiate sans friction** tout en offrant une **progression naturelle** vers les fonctionnalités avancées.

### Principe de Base
- **Invité** : UUID temporaire, données locales ou temporaires
- **Compte** : Authentification complète, synchronisation, collaboration
- **Migration** : Transition transparente des données invité vers compte

## 🏗️ Architecture Refactorisée

### 1. Table des Utilisateurs Hybride

```sql
-- Table des utilisateurs (hybride invité/compte)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification
    email CITEXT UNIQUE, -- NULL pour les invités
    password_hash VARCHAR(255), -- NULL pour les invités
    username VARCHAR(50) UNIQUE, -- NULL pour les invités
    display_name VARCHAR(100) NOT NULL DEFAULT 'Utilisateur Invité',
    
    -- Type d'utilisateur
    user_type VARCHAR(20) NOT NULL DEFAULT 'guest' CHECK (user_type IN ('guest', 'registered', 'migrated')),
    
    -- Données invité
    anonymous_id UUID UNIQUE, -- UUID généré côté client pour les invités
    session_expires_at TIMESTAMP WITH TIME ZONE, -- Expiration pour les invités
    
    -- Données compte
    avatar_url TEXT,
    bio TEXT,
    location VARCHAR(100),
    website VARCHAR(255),
    
    -- Statut et vérification (uniquement pour les comptes)
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Préférences
    theme VARCHAR(10) DEFAULT 'dark' CHECK (theme IN ('light', 'dark', 'auto')),
    language VARCHAR(5) DEFAULT 'fr' CHECK (language IN ('fr', 'en', 'es')),
    timezone VARCHAR(50) DEFAULT 'Europe/Paris',
    
    -- Statistiques
    public_snippets_count INT DEFAULT 0,
    public_projects_count INT DEFAULT 0,
    contributions_count INT DEFAULT 0,
    
    -- Migration
    migrated_from_anonymous_id UUID, -- Référence vers l'ancien ID invité
    migrated_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT users_email_required_for_registered 
        CHECK (user_type = 'guest' OR email IS NOT NULL),
    CONSTRAINT users_password_required_for_registered 
        CHECK (user_type = 'guest' OR password_hash IS NOT NULL),
    CONSTRAINT users_anonymous_id_required_for_guest 
        CHECK (user_type != 'guest' OR anonymous_id IS NOT NULL)
);

-- Index pour performance
CREATE INDEX idx_users_anonymous_id ON users(anonymous_id) WHERE anonymous_id IS NOT NULL;
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_session_expires ON users(session_expires_at) WHERE session_expires_at IS NOT NULL;
```

### 2. Système de Sessions Hybride

```sql
-- Table des sessions (hybride)
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Type de session
    session_type VARCHAR(20) NOT NULL CHECK (session_type IN ('guest', 'authenticated')),
    
    -- Tokens
    token_hash VARCHAR(255) NOT NULL,
    refresh_token_hash VARCHAR(255), -- NULL pour les invités
    
    -- Métadonnées
    device_info JSONB,
    ip_address INET,
    user_agent TEXT,
    
    -- Expiration
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Persistance (pour les invités)
    is_persistent BOOLEAN DEFAULT FALSE, -- Si l'invité veut sauvegarder ses données
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour nettoyage automatique
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_type ON user_sessions(session_type);
```

### 3. Système de Migration

```sql
-- Table de suivi des migrations
CREATE TABLE user_migrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Utilisateur source (invité) et destination (compte)
    source_anonymous_id UUID NOT NULL,
    destination_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Statut de la migration
    migration_status VARCHAR(20) DEFAULT 'pending' CHECK (migration_status IN ('pending', 'in_progress', 'completed', 'failed')),
    
    -- Détails de la migration
    entities_migrated JSONB DEFAULT '{}', -- Compteurs par type d'entité
    migration_log JSONB DEFAULT '[]', -- Log des étapes
    
    -- Métadonnées
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🔧 Fonctions de Migration

### Migration Automatique
```sql
-- Fonction pour migrer les données d'un invité vers un compte
CREATE OR REPLACE FUNCTION migrate_guest_to_registered_user(
    p_anonymous_id UUID,
    p_email CITEXT,
    p_password_hash VARCHAR(255),
    p_username VARCHAR(50),
    p_display_name VARCHAR(100)
) RETURNS UUID AS $$
DECLARE
    guest_user_id UUID;
    new_user_id UUID;
    migration_id UUID;
    entity_counts JSONB;
BEGIN
    -- Trouver l'utilisateur invité
    SELECT id INTO guest_user_id
    FROM users
    WHERE anonymous_id = p_anonymous_id AND user_type = 'guest';
    
    IF guest_user_id IS NULL THEN
        RAISE EXCEPTION 'Guest user not found for anonymous_id: %', p_anonymous_id;
    END IF;
    
    -- Créer le nouvel utilisateur enregistré
    INSERT INTO users (
        email, password_hash, username, display_name,
        user_type, migrated_from_anonymous_id, migrated_at,
        theme, language, timezone
    )
    SELECT 
        p_email, p_password_hash, p_username, p_display_name,
        'migrated', p_anonymous_id, NOW(),
        theme, language, timezone
    FROM users 
    WHERE id = guest_user_id
    RETURNING id INTO new_user_id;
    
    -- Créer un enregistrement de migration
    INSERT INTO user_migrations (source_anonymous_id, destination_user_id, migration_status)
    VALUES (p_anonymous_id, new_user_id, 'in_progress')
    RETURNING id INTO migration_id;
    
    -- Migrer les projets
    UPDATE projects SET owner_id = new_user_id WHERE owner_id = guest_user_id;
    
    -- Migrer les notes
    UPDATE project_notes SET author_id = new_user_id WHERE author_id = guest_user_id;
    
    -- Migrer les snippets
    UPDATE project_snippets SET author_id = new_user_id WHERE author_id = guest_user_id;
    UPDATE public_snippets SET author_id = new_user_id WHERE author_id = guest_user_id;
    
    -- Migrer les tâches
    UPDATE tasks SET author_id = new_user_id WHERE author_id = guest_user_id;
    UPDATE tasks SET assignee_id = new_user_id WHERE assignee_id = guest_user_id;
    
    -- Migrer les permissions de projet
    UPDATE project_permissions SET user_id = new_user_id WHERE user_id = guest_user_id;
    
    -- Compter les entités migrées
    entity_counts := jsonb_build_object(
        'projects', (SELECT COUNT(*) FROM projects WHERE owner_id = new_user_id),
        'notes', (SELECT COUNT(*) FROM project_notes WHERE author_id = new_user_id),
        'snippets', (SELECT COUNT(*) FROM project_snippets WHERE author_id = new_user_id),
        'public_snippets', (SELECT COUNT(*) FROM public_snippets WHERE author_id = new_user_id),
        'tasks', (SELECT COUNT(*) FROM tasks WHERE author_id = new_user_id)
    );
    
    -- Marquer la migration comme terminée
    UPDATE user_migrations 
    SET migration_status = 'completed', 
        completed_at = NOW(),
        entities_migrated = entity_counts
    WHERE id = migration_id;
    
    -- Marquer l'ancien utilisateur comme migré (garder pour l'historique)
    UPDATE users 
    SET user_type = 'migrated', 
        is_active = FALSE,
        updated_at = NOW()
    WHERE id = guest_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;
```

## 🔐 Système d'Authentification Hybride

### Middleware d'Authentification Flexible
```rust
// Structure pour l'utilisateur hybride
#[derive(Debug, Clone)]
pub struct HybridUser {
    pub id: Uuid,
    pub user_type: UserType,
    pub email: Option<String>,
    pub username: Option<String>,
    pub display_name: String,
    pub anonymous_id: Option<Uuid>,
    pub is_authenticated: bool,
    pub permissions: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum UserType {
    Guest,
    Registered,
    Migrated,
}

// Middleware d'authentification flexible
pub async fn hybrid_auth_middleware(
    req: Request<Body>,
    next: Next<Body>,
) -> Result<Response, AppError> {
    let user = match extract_user_from_request(&req).await {
        Ok(user) => user,
        Err(_) => {
            // Si pas d'auth, créer un utilisateur invité temporaire
            create_guest_user(&req).await?
        }
    };
    
    // Ajouter l'utilisateur au contexte de la requête
    req.extensions_mut().insert(user);
    
    Ok(next.run(req).await)
}

// Extraction de l'utilisateur depuis la requête
async fn extract_user_from_request(req: &Request<Body>) -> Result<HybridUser, AppError> {
    // 1. Vérifier le token JWT (utilisateur enregistré)
    if let Some(token) = extract_jwt_token(req) {
        return validate_jwt_user(token).await;
    }
    
    // 2. Vérifier l'anonymous_id (utilisateur invité)
    if let Some(anonymous_id) = extract_anonymous_id(req) {
        return load_guest_user(anonymous_id).await;
    }
    
    Err(AppError::Unauthorized)
}

// Création d'un utilisateur invité
async fn create_guest_user(req: &Request<Body>) -> Result<HybridUser, AppError> {
    let anonymous_id = Uuid::new_v4();
    let ip_address = extract_ip_address(req);
    let user_agent = extract_user_agent(req);
    
    // Créer l'utilisateur invité en base
    let user_id = sqlx::query!(
        r#"
        INSERT INTO users (anonymous_id, user_type, display_name, session_expires_at)
        VALUES ($1, 'guest', 'Utilisateur Invité', $2)
        RETURNING id
        "#,
        anonymous_id,
        chrono::Utc::now() + chrono::Duration::hours(24) // Expire dans 24h
    )
    .fetch_one(&db_pool)
    .await?
    .id;
    
    // Créer une session invité
    create_guest_session(user_id, anonymous_id, ip_address, user_agent).await?;
    
    Ok(HybridUser {
        id: user_id,
        user_type: UserType::Guest,
        email: None,
        username: None,
        display_name: "Utilisateur Invité".to_string(),
        anonymous_id: Some(anonymous_id),
        is_authenticated: false,
        permissions: vec!["guest_access".to_string()],
    })
}
```

## 📊 APIs Hybrides

### Endpoints d'Authentification
```rust
// Création d'un compte depuis un invité
POST /api/auth/register-from-guest
{
    "anonymous_id": "uuid",
    "email": "user@example.com",
    "password": "password",
    "username": "username",
    "display_name": "Display Name"
}

// Authentification classique
POST /api/auth/login
{
    "email": "user@example.com",
    "password": "password"
}

// Connexion d'un invité existant
POST /api/auth/guest-session
{
    "anonymous_id": "uuid" // Optionnel, généré si absent
}

// Statut de l'utilisateur actuel
GET /api/auth/status
```

### Endpoints de Migration
```rust
// Démarrer une migration
POST /api/user/migrate
{
    "email": "user@example.com",
    "password": "password",
    "username": "username",
    "display_name": "Display Name"
}

// Statut de la migration
GET /api/user/migration-status

// Données migrables (preview)
GET /api/user/migration-preview
```

## 🔒 Système de Permissions Hybride

### Permissions par Type d'Utilisateur
```sql
-- Permissions par défaut selon le type d'utilisateur
CREATE TABLE default_permissions (
    user_type VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (user_type, permission)
);

-- Permissions pour les invités
INSERT INTO default_permissions (user_type, permission) VALUES
('guest', 'create_projects'),
('guest', 'edit_own_projects'),
('guest', 'delete_own_projects'),
('guest', 'create_notes'),
('guest', 'edit_own_notes'),
('guest', 'delete_own_notes'),
('guest', 'create_snippets'),
('guest', 'edit_own_snippets'),
('guest', 'delete_own_snippets'),
('guest', 'create_tasks'),
('guest', 'edit_own_tasks'),
('guest', 'delete_own_tasks'),
('guest', 'export_data');

-- Permissions additionnelles pour les comptes
INSERT INTO default_permissions (user_type, permission) VALUES
('registered', 'sync_data'),
('registered', 'share_projects'),
('registered', 'collaborate'),
('registered', 'access_history'),
('registered', 'publish_snippets'),
('registered', 'fork_snippets'),
('registered', 'like_snippets'),
('registered', 'comment'),
('registered', 'report_content');
```

## 🗄️ Gestion des Données Temporaires

### Nettoyage Automatique
```sql
-- Fonction pour nettoyer les données expirées
CREATE OR REPLACE FUNCTION cleanup_expired_guest_data() RETURNS VOID AS $$
BEGIN
    -- Supprimer les sessions expirées
    DELETE FROM user_sessions WHERE expires_at < NOW();
    
    -- Supprimer les utilisateurs invités expirés (sans persistance)
    DELETE FROM users 
    WHERE user_type = 'guest' 
      AND session_expires_at < NOW()
      AND id NOT IN (
          SELECT DISTINCT user_id 
          FROM user_sessions 
          WHERE session_type = 'guest' 
            AND is_persistent = TRUE
      );
    
    -- Nettoyer les données orphelines
    DELETE FROM projects WHERE owner_id NOT IN (SELECT id FROM users);
    DELETE FROM project_notes WHERE author_id NOT IN (SELECT id FROM users);
    DELETE FROM project_snippets WHERE author_id NOT IN (SELECT id FROM users);
    DELETE FROM tasks WHERE author_id NOT IN (SELECT id FROM users);
END;
$$ LANGUAGE plpgsql;

-- Tâche cron pour nettoyage quotidien
SELECT cron.schedule('cleanup-guest-data', '0 3 * * *', 'SELECT cleanup_expired_guest_data()');
```

## 🔄 Workflow Utilisateur

### Parcours Invité → Compte
1. **Arrivée** : Génération automatique d'un `anonymous_id`
2. **Utilisation** : Création de projets, notes, snippets sans contrainte
3. **Découverte** : Accès aux fonctionnalités avancées limité
4. **Conversion** : Création de compte avec migration automatique
5. **Enrichissement** : Accès complet aux fonctionnalités collaboratives

### Gestion de l'Expiration
- **Invités temporaires** : Expiration automatique après 24h d'inactivité
- **Invités persistants** : Données sauvegardées localement, pas d'expiration
- **Migration** : Transfert permanent vers un compte authentifié

Ce système hybride offre la **flexibilité maximale** tout en respectant la philosophie d'ETTU : **accessibilité immédiate** avec **progression naturelle** vers les fonctionnalités avancées ! 🚀
