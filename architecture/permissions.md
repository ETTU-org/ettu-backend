# Système de Permissions ETTU

## Vue d'ensemble

Le système de permissions d'ETTU est conçu pour être **flexible**, **granulaire** et **sécurisé**, supportant à la fois les utilisateurs invités et les comptes enregistrés.

## Architecture des permissions

### Types d'utilisateurs et permissions

```sql
-- Permissions par défaut selon le type d'utilisateur
CREATE TABLE default_permissions (
    user_type VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (user_type, permission)
);
```

### Permissions globales

#### Utilisateurs invités (guest)
- `create_projects`: Créer des projets
- `edit_own_projects`: Modifier ses propres projets
- `delete_own_projects`: Supprimer ses propres projets
- `create_notes`: Créer des notes
- `edit_own_notes`: Modifier ses propres notes
- `delete_own_notes`: Supprimer ses propres notes
- `create_snippets`: Créer des snippets
- `edit_own_snippets`: Modifier ses propres snippets
- `delete_own_snippets`: Supprimer ses propres snippets
- `create_tasks`: Créer des tâches
- `edit_own_tasks`: Modifier ses propres tâches
- `delete_own_tasks`: Supprimer ses propres tâches
- `export_data`: Exporter ses données
- `view_public_snippets`: Voir les snippets publics

#### Utilisateurs enregistrés (registered/migrated)
Héritent de toutes les permissions invité **plus** :
- `sync_data`: Synchroniser les données
- `share_projects`: Partager des projets
- `collaborate`: Collaborer sur des projets
- `access_history`: Accéder à l'historique
- `publish_snippets`: Publier des snippets
- `fork_snippets`: Forker des snippets
- `like_snippets`: Aimer des snippets
- `comment`: Commenter
- `report_content`: Signaler du contenu

### Permissions sur les projets

```sql
-- Permissions spécifiques aux projets
CREATE TABLE project_permissions (
    project_id UUID REFERENCES projects(id),
    user_id UUID REFERENCES users(id),
    role VARCHAR(20) NOT NULL,
    
    -- Permissions granulaires
    can_edit_project BOOLEAN DEFAULT FALSE,
    can_manage_members BOOLEAN DEFAULT FALSE,
    can_create_notes BOOLEAN DEFAULT FALSE,
    can_edit_notes BOOLEAN DEFAULT FALSE,
    can_delete_notes BOOLEAN DEFAULT FALSE,
    can_create_snippets BOOLEAN DEFAULT FALSE,
    can_edit_snippets BOOLEAN DEFAULT FALSE,
    can_delete_snippets BOOLEAN DEFAULT FALSE,
    can_create_tasks BOOLEAN DEFAULT FALSE,
    can_edit_tasks BOOLEAN DEFAULT FALSE,
    can_delete_tasks BOOLEAN DEFAULT FALSE
);
```

#### Rôles de projet

1. **Owner** (propriétaire)
   - Toutes les permissions
   - Peut transférer la propriété
   - Peut supprimer le projet

2. **Admin** (administrateur)
   - Toutes les permissions sauf transfert/suppression
   - Peut gérer les membres
   - Peut modifier les paramètres du projet

3. **Editor** (éditeur)
   - Peut créer/modifier le contenu
   - Ne peut pas gérer les membres
   - Ne peut pas modifier les paramètres

4. **Viewer** (lecteur)
   - Lecture seule
   - Peut commenter si activé
   - Peut voir l'historique

### Permissions administratives

```sql
-- Rôles globaux pour l'administration
CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id),
    role VARCHAR(20) NOT NULL,
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Permissions par rôle
CREATE TABLE role_permissions (
    role VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT TRUE
);
```

#### Rôles administratifs

1. **admin**: Administrateur système
   - Toutes les permissions
   - Gestion des utilisateurs
   - Configuration système

2. **moderator**: Modérateur
   - Modération du contenu
   - Gestion des signalements
   - Sanctions temporaires

3. **reviewer**: Réviseur
   - Validation des snippets publics
   - Modération légère
   - Gestion des rapports

4. **user**: Utilisateur standard
   - Permissions de base uniquement

5. **restricted**: Utilisateur restreint
   - Permissions limitées
   - Soumis à validation

## Fonctions de vérification

### Vérification des permissions globales

```sql
CREATE OR REPLACE FUNCTION user_has_permission(
    p_user_id UUID,
    p_permission VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    user_type_val VARCHAR(20);
    has_permission BOOLEAN := FALSE;
BEGIN
    -- Obtenir le type d'utilisateur
    SELECT user_type INTO user_type_val
    FROM users WHERE id = p_user_id;
    
    -- Vérifier les permissions par défaut
    SELECT is_granted INTO has_permission
    FROM default_permissions
    WHERE user_type = user_type_val AND permission = p_permission;
    
    -- Vérifier les rôles si utilisateur enregistré
    IF has_permission IS NULL AND user_type_val IN ('registered', 'migrated') THEN
        has_permission := EXISTS(
            SELECT 1 FROM role_permissions rp
            JOIN user_roles ur ON ur.role = rp.role
            WHERE ur.user_id = p_user_id 
              AND rp.permission = p_permission
              AND rp.is_granted = TRUE
        );
    END IF;
    
    RETURN COALESCE(has_permission, FALSE);
END;
$$ LANGUAGE plpgsql;
```

### Vérification des permissions sur les projets

```sql
CREATE OR REPLACE FUNCTION user_has_project_permission(
    p_user_id UUID,
    p_project_id UUID,
    p_permission VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    user_role VARCHAR(20);
    project_owner UUID;
    has_permission BOOLEAN := FALSE;
BEGIN
    -- Vérifier si propriétaire
    SELECT owner_id INTO project_owner
    FROM projects WHERE id = p_project_id;
    
    IF project_owner = p_user_id THEN
        RETURN TRUE;
    END IF;
    
    -- Récupérer le rôle de l'utilisateur
    SELECT role INTO user_role
    FROM project_permissions
    WHERE project_id = p_project_id AND user_id = p_user_id;
    
    -- Vérifier selon le rôle
    has_permission := CASE user_role
        WHEN 'admin' THEN TRUE
        WHEN 'editor' THEN p_permission NOT IN ('can_manage_members', 'can_edit_project')
        WHEN 'viewer' THEN p_permission IN ('can_view')
        ELSE FALSE
    END;
    
    RETURN has_permission;
END;
$$ LANGUAGE plpgsql;
```

## Limites par type d'utilisateur

### Utilisateurs invités

```rust
pub const GUEST_LIMITS: GuestLimits = GuestLimits {
    max_projects: 5,
    max_notes_per_project: 10,
    max_snippets_per_project: 10,
    max_tasks_per_project: 20,
    max_storage_mb: 50,
    max_collaborators: 0, // Pas de collaboration
    session_duration_days: 30,
};
```

### Utilisateurs enregistrés

```rust
pub const REGISTERED_LIMITS: RegisteredLimits = RegisteredLimits {
    max_projects: 100,
    max_notes_per_project: 1000,
    max_snippets_per_project: 500,
    max_tasks_per_project: 1000,
    max_storage_mb: 1000,
    max_collaborators: 10,
    max_public_snippets: 50,
    session_duration_days: 7, // Avec refresh
};
```

## Middleware de permissions

```rust
pub async fn check_permission_middleware(
    Extension(current_user): Extension<CurrentUser>,
    req: Request<Body>,
    next: Next<Body>,
) -> Result<Response, StatusCode> {
    let permission = extract_required_permission(&req);
    
    if !user_has_permission(&current_user, &permission).await? {
        return Err(StatusCode::FORBIDDEN);
    }
    
    Ok(next.run(req).await)
}

pub async fn check_project_permission_middleware(
    Extension(current_user): Extension<CurrentUser>,
    Path(project_id): Path<Uuid>,
    req: Request<Body>,
    next: Next<Body>,
) -> Result<Response, StatusCode> {
    let permission = extract_required_permission(&req);
    
    if !user_has_project_permission(&current_user, &project_id, &permission).await? {
        return Err(StatusCode::FORBIDDEN);
    }
    
    Ok(next.run(req).await)
}
```

## Escalade des permissions

### Migration invité → enregistré

Lors de la migration, l'utilisateur gagne automatiquement toutes les permissions supplémentaires des comptes enregistrés.

### Attribution de rôles

```sql
-- Attribuer un rôle temporaire
INSERT INTO user_roles (user_id, role, granted_by, expires_at)
VALUES (user_id, 'moderator', admin_id, NOW() + INTERVAL '30 days');

-- Attribuer un rôle permanent
INSERT INTO user_roles (user_id, role, granted_by)
VALUES (user_id, 'reviewer', admin_id);
```

### Révocation

```sql
-- Révoquer un rôle
DELETE FROM user_roles 
WHERE user_id = target_user_id AND role = 'moderator';

-- Révoquer toutes les permissions d'un utilisateur
UPDATE users SET user_type = 'restricted' WHERE id = user_id;
```

## Audit des permissions

Toutes les modifications de permissions sont auditées :

```sql
-- Trigger automatique sur les changements de permissions
CREATE TRIGGER audit_permissions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_permissions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_roles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

## Tests de permissions

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_guest_permissions() {
        let guest = create_guest_user().await;
        
        assert!(user_has_permission(&guest, "create_projects").await);
        assert!(!user_has_permission(&guest, "share_projects").await);
    }
    
    #[tokio::test]
    async fn test_project_permissions() {
        let project = create_test_project().await;
        let editor = create_editor_user(&project).await;
        
        assert!(user_has_project_permission(&editor, &project.id, "can_create_notes").await);
        assert!(!user_has_project_permission(&editor, &project.id, "can_manage_members").await);
    }
}
```

## Sécurité

### Principe du moindre privilège

Par défaut, les utilisateurs ont le minimum de permissions nécessaires.

### Défense en profondeur

- Vérification côté middleware
- Vérification côté base de données
- Vérification côté frontend (UI)

### Audit trail

Toutes les actions sensibles sont loggées avec :
- Qui a fait quoi
- Quand
- Avec quelles permissions
- Résultat de l'action
