# Configuration commune pour l'architecture ETTU Backend

Ce fichier centralise les configurations communes utilisées dans tous les composants du backend.

## Types d'utilisateurs

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum UserType {
    Guest,
    Registered,
    Migrated,
}
```

## Permissions de base

```rust
pub const GUEST_PERMISSIONS: &[&str] = &[
    "create_projects",
    "edit_own_projects", 
    "delete_own_projects",
    "create_notes",
    "edit_own_notes",
    "delete_own_notes",
    "create_snippets",
    "edit_own_snippets",
    "delete_own_snippets",
    "create_tasks",
    "edit_own_tasks",
    "delete_own_tasks",
    "export_data",
    "view_public_snippets",
];

pub const REGISTERED_PERMISSIONS: &[&str] = &[
    // Toutes les permissions guest +
    "sync_data",
    "share_projects",
    "collaborate", 
    "access_history",
    "publish_snippets",
    "fork_snippets",
    "like_snippets",
    "comment",
    "report_content",
];
```

## Rôles de projet

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProjectRole {
    Owner,
    Admin,
    Editor,
    Viewer,
}
```

## Statuts des entités

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProjectStatus {
    Active,
    Paused,
    Completed,
    Archived,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TaskStatus {
    Backlog,
    InProgress,
    Testing,
    Done,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TaskPriority {
    Low,
    Medium,
    High,
    Urgent,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ModerationStatus {
    Pending,
    Approved,
    Rejected,
    Flagged,
}
```

## Configuration des sessions

```rust
pub const GUEST_SESSION_DURATION: Duration = Duration::from_secs(30 * 24 * 60 * 60); // 30 jours
pub const REGISTERED_SESSION_DURATION: Duration = Duration::from_secs(7 * 24 * 60 * 60); // 7 jours
pub const REFRESH_TOKEN_DURATION: Duration = Duration::from_secs(30 * 24 * 60 * 60); // 30 jours
```

## Messages d'erreur standardisés

```rust
pub const ERROR_MESSAGES: &[(&str, &str)] = &[
    ("UNAUTHORIZED", "Vous n'êtes pas autorisé à effectuer cette action"),
    ("FORBIDDEN", "Accès refusé"),
    ("NOT_FOUND", "Ressource non trouvée"),
    ("VALIDATION_ERROR", "Données invalides"),
    ("MIGRATION_ERROR", "Erreur lors de la migration des données"),
    ("GUEST_LIMIT_EXCEEDED", "Limite d'utilisation invité atteinte"),
];
```

## Limites par type d'utilisateur

```rust
pub const GUEST_LIMITS: &[(&str, u32)] = &[
    ("max_projects", 5),
    ("max_notes_per_project", 10),
    ("max_snippets_per_project", 10),
    ("max_tasks_per_project", 20),
    ("max_storage_mb", 50),
];

pub const REGISTERED_LIMITS: &[(&str, u32)] = &[
    ("max_projects", 100),
    ("max_notes_per_project", 1000),
    ("max_snippets_per_project", 500),
    ("max_tasks_per_project", 1000),
    ("max_storage_mb", 1000),
];
```

## Configuration Redis

```rust
pub const REDIS_KEYS: &[(&str, &str)] = &[
    ("session_prefix", "ettu:session:"),
    ("user_cache_prefix", "ettu:user:"),
    ("project_cache_prefix", "ettu:project:"),
    ("rate_limit_prefix", "ettu:rate:"),
    ("migration_lock_prefix", "ettu:migration:"),
];
```

## Événements WebSocket

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum WebSocketEvent {
    ProjectUpdated { project_id: Uuid },
    NoteAdded { project_id: Uuid, note_id: Uuid },
    TaskStatusChanged { project_id: Uuid, task_id: Uuid, status: TaskStatus },
    UserJoined { project_id: Uuid, user_id: Uuid },
    UserLeft { project_id: Uuid, user_id: Uuid },
    ChatMessage { conversation_id: Uuid, message_id: Uuid },
}
```

## Configuration des logs d'audit

```rust
pub const AUDIT_RETENTION_POLICIES: &[(&str, &str)] = &[
    ("short", "3 months"),
    ("standard", "2 years"),
    ("long", "7 years"),
    ("permanent", "never"),
];

pub const AUDIT_CATEGORIES: &[&str] = &[
    "user_action",
    "system_action", 
    "moderation",
    "security",
];
```
