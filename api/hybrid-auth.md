# ETTU - APIs du Système Hybride

## 🔐 Endpoints d'Authentification Hybride

### 1. Création d'une session invité
```http
POST /api/auth/guest-session
Content-Type: application/json

{
  "anonymous_id": "uuid-optionnel", // Si omis, généré automatiquement
  "persistent": false, // Sauvegarder les données après expiration
  "device_info": {
    "platform": "web",
    "browser": "Chrome",
    "version": "91.0"
  }
}

Response 200:
{
  "success": true,
  "user": {
    "id": "user-uuid",
    "anonymous_id": "anonymous-uuid",
    "user_type": "guest",
    "display_name": "Utilisateur Invité",
    "is_authenticated": false,
    "session_expires_at": "2023-07-17T12:00:00Z",
    "permissions": ["create_projects", "edit_own_projects", ...]
  },
  "session": {
    "token": "guest-session-token",
    "expires_at": "2023-07-17T12:00:00Z"
  }
}
```

### 2. Connexion d'un invité existant
```http
POST /api/auth/guest-reconnect
Content-Type: application/json

{
  "anonymous_id": "existing-anonymous-uuid"
}

Response 200:
{
  "success": true,
  "user": {
    "id": "user-uuid",
    "anonymous_id": "anonymous-uuid",
    "user_type": "guest",
    "display_name": "Utilisateur Invité",
    "is_authenticated": false,
    "session_expires_at": "2023-07-17T12:00:00Z",
    "permissions": ["create_projects", "edit_own_projects", ...]
  },
  "session": {
    "token": "guest-session-token",
    "expires_at": "2023-07-17T12:00:00Z"
  }
}
```

### 3. Inscription depuis un invité
```http
POST /api/auth/register-from-guest
Content-Type: application/json

{
  "anonymous_id": "guest-anonymous-uuid",
  "email": "user@example.com",
  "password": "securepassword",
  "username": "username",
  "display_name": "John Doe"
}

Response 200:
{
  "success": true,
  "user": {
    "id": "new-user-uuid",
    "email": "user@example.com",
    "username": "username",
    "display_name": "John Doe",
    "user_type": "migrated",
    "is_authenticated": true,
    "migrated_from_anonymous_id": "guest-anonymous-uuid",
    "migrated_at": "2023-07-16T15:30:00Z",
    "permissions": ["create_projects", "sync_data", "collaborate", ...]
  },
  "session": {
    "token": "jwt-access-token",
    "refresh_token": "jwt-refresh-token",
    "expires_at": "2023-07-17T15:30:00Z"
  },
  "migration": {
    "id": "migration-uuid",
    "status": "completed",
    "entities_migrated": {
      "projects": 5,
      "notes": 23,
      "snippets": 12,
      "tasks": 8
    }
  }
}
```

### 4. Authentification classique
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}

Response 200:
{
  "success": true,
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "username": "username",
    "display_name": "John Doe",
    "user_type": "registered",
    "is_authenticated": true,
    "permissions": ["create_projects", "sync_data", "collaborate", ...]
  },
  "session": {
    "token": "jwt-access-token",
    "refresh_token": "jwt-refresh-token",
    "expires_at": "2023-07-17T15:30:00Z"
  }
}
```

### 5. Statut de l'utilisateur actuel
```http
GET /api/auth/status
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "user": {
    "id": "user-uuid",
    "user_type": "guest|registered|migrated",
    "is_authenticated": true|false,
    "display_name": "Display Name",
    "anonymous_id": "uuid-or-null",
    "email": "email-or-null",
    "username": "username-or-null",
    "session_expires_at": "2023-07-17T12:00:00Z",
    "permissions": ["list", "of", "permissions"]
  },
  "session": {
    "expires_at": "2023-07-17T12:00:00Z",
    "is_persistent": true|false
  }
}
```

## 🔄 Endpoints de Migration

### 1. Prévisualisation des données migrables
```http
GET /api/user/migration-preview
Authorization: Bearer <guest-token>

Response 200:
{
  "success": true,
  "preview": {
    "projects": {
      "count": 5,
      "examples": [
        {
          "id": "project-uuid",
          "name": "Mon Projet",
          "description": "Description du projet",
          "created_at": "2023-07-15T10:00:00Z"
        }
      ]
    },
    "notes": {
      "count": 23,
      "examples": [
        {
          "id": "note-uuid",
          "title": "Ma Note",
          "type": "brief",
          "created_at": "2023-07-15T11:00:00Z"
        }
      ]
    },
    "snippets": {
      "count": 12,
      "examples": [
        {
          "id": "snippet-uuid",
          "title": "Mon Snippet",
          "language": "javascript",
          "created_at": "2023-07-15T12:00:00Z"
        }
      ]
    },
    "tasks": {
      "count": 8,
      "examples": [
        {
          "id": "task-uuid",
          "title": "Ma Tâche",
          "status": "in-progress",
          "created_at": "2023-07-15T13:00:00Z"
        }
      ]
    }
  }
}
```

### 2. Démarrer une migration
```http
POST /api/user/migrate
Authorization: Bearer <guest-token>
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword",
  "username": "username",
  "display_name": "John Doe",
  "migrate_all": true, // Migrer toutes les données
  "entities_to_migrate": { // Optionnel si migrate_all = false
    "projects": true,
    "notes": true,
    "snippets": true,
    "tasks": true
  }
}

Response 202:
{
  "success": true,
  "migration": {
    "id": "migration-uuid",
    "status": "in_progress",
    "started_at": "2023-07-16T15:30:00Z",
    "estimated_duration": "30 seconds"
  }
}
```

### 3. Statut d'une migration
```http
GET /api/user/migration-status
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "migration": {
    "id": "migration-uuid",
    "status": "completed|in_progress|failed",
    "started_at": "2023-07-16T15:30:00Z",
    "completed_at": "2023-07-16T15:30:45Z",
    "entities_migrated": {
      "projects": 5,
      "notes": 23,
      "snippets": 12,
      "tasks": 8
    },
    "migration_log": [
      {
        "timestamp": "2023-07-16T15:30:00Z",
        "step": "migration_started",
        "message": "Migration started"
      },
      {
        "timestamp": "2023-07-16T15:30:15Z",
        "step": "projects_migrated",
        "message": "5 projects migrated successfully"
      },
      {
        "timestamp": "2023-07-16T15:30:30Z",
        "step": "notes_migrated",
        "message": "23 notes migrated successfully"
      },
      {
        "timestamp": "2023-07-16T15:30:45Z",
        "step": "migration_completed",
        "message": "Migration completed successfully"
      }
    ]
  }
}
```

## 🛠️ Endpoints de Gestion des Données

### 1. Export des données (invité et compte)
```http
GET /api/user/export
Authorization: Bearer <token>
Query Parameters:
- format=json|csv|xml (default: json)
- entities=projects,notes,snippets,tasks (default: all)
- include_metadata=true|false (default: false)

Response 200:
{
  "success": true,
  "export": {
    "format": "json",
    "generated_at": "2023-07-16T16:00:00Z",
    "user_type": "guest|registered|migrated",
    "entities": {
      "projects": [...],
      "notes": [...],
      "snippets": [...],
      "tasks": [...]
    },
    "metadata": {
      "total_entities": 48,
      "creation_date_range": {
        "first": "2023-07-10T09:00:00Z",
        "last": "2023-07-16T15:45:00Z"
      }
    }
  }
}
```

### 2. Import des données (compte uniquement)
```http
POST /api/user/import
Authorization: Bearer <authenticated-token>
Content-Type: multipart/form-data

file: <exported-data-file>
merge_strategy: replace|merge|skip (default: merge)

Response 200:
{
  "success": true,
  "import": {
    "imported_at": "2023-07-16T16:15:00Z",
    "entities_imported": {
      "projects": 3,
      "notes": 15,
      "snippets": 8,
      "tasks": 5
    },
    "conflicts_resolved": 2,
    "errors": []
  }
}
```

### 3. Purge des données invité
```http
DELETE /api/user/purge-guest-data
Authorization: Bearer <guest-token>

Response 200:
{
  "success": true,
  "purged": {
    "projects": 5,
    "notes": 23,
    "snippets": 12,
    "tasks": 8
  },
  "message": "All guest data has been permanently deleted"
}
```

## 🔒 Endpoints de Permissions

### 1. Vérifier les permissions
```http
GET /api/user/permissions
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "permissions": {
    "create_projects": true,
    "edit_own_projects": true,
    "delete_own_projects": true,
    "sync_data": false, // Pas disponible pour les invités
    "share_projects": false,
    "collaborate": false,
    "access_history": false,
    "publish_snippets": false,
    "fork_snippets": false,
    "like_snippets": false,
    "comment": false,
    "report_content": false
  },
  "user_type": "guest|registered|migrated",
  "upgrade_available": true|false
}
```

### 2. Fonctionnalités disponibles selon le type d'utilisateur
```http
GET /api/user/available-features
Authorization: Bearer <token>

Response 200:
{
  "success": true,
  "features": {
    "current_type": "guest",
    "available": {
      "local_storage": true,
      "project_management": true,
      "note_taking": true,
      "snippet_management": true,
      "task_management": true,
      "data_export": true
    },
    "upgrade_benefits": {
      "cloud_sync": "Synchronisation multi-appareils",
      "collaboration": "Partage et collaboration en temps réel",
      "version_history": "Historique des modifications",
      "public_snippets": "Publication dans la banque de snippets",
      "community_features": "Likes, commentaires, forks"
    }
  }
}
```

## 📊 Middleware de Validation

### Headers requis
```
Authorization: Bearer <token>
Content-Type: application/json
X-Anonymous-ID: <uuid> (optionnel pour les invités)
```

### Codes de réponse
- `200` : Succès
- `201` : Créé avec succès
- `202` : Accepté (traitement asynchrone)
- `400` : Données invalides
- `401` : Non authentifié
- `403` : Permission insuffisante
- `404` : Ressource non trouvée
- `409` : Conflit (ex: email déjà utilisé)
- `429` : Trop de requêtes
- `500` : Erreur serveur

### Gestion des erreurs
```json
{
  "success": false,
  "error": {
    "code": "MIGRATION_FAILED",
    "message": "La migration a échoué en raison d'un conflit de données",
    "details": {
      "conflicting_entities": ["project_1", "note_5"],
      "suggested_action": "merge_strategy"
    }
  }
}
```

Ce système d'APIs hybride permet une **transition fluide** entre les modes invité et authentifié tout en respectant les permissions et la sécurité ! 🚀
