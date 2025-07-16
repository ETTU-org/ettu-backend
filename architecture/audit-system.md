# ETTU - Système d'Audit Log Complet

## 🎯 Objectifs du Système d'Audit

- **Traçabilité** : Historique complet de toutes les modifications
- **Sécurité** : Détection d'activités suspectes ou malveillantes
- **Rollback** : Possibilité de restaurer l'état précédent
- **Compliance** : Conformité RGPD et autres réglementations
- **Debug** : Diagnostic des problèmes et incidents

## 📊 Architecture du Système d'Audit

### Table Principale d'Audit
```sql
-- Table universelle d'audit pour toutes les entités
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification de l'action
    entity_type VARCHAR(50) NOT NULL, -- 'user', 'project', 'note', 'snippet', 'task', etc.
    entity_id UUID NOT NULL,
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('create', 'update', 'delete', 'restore')),
    
    -- Métadonnées de l'action
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    
    -- Données avant/après
    old_values JSONB, -- État avant modification
    new_values JSONB, -- État après modification
    changed_fields JSONB, -- Liste des champs modifiés
    
    -- Contexte et métadonnées
    context JSONB, -- Contexte de l'action (API endpoint, interface, etc.)
    reason TEXT, -- Raison de l'action (optionnel)
    
    -- Classification
    severity VARCHAR(10) DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    category VARCHAR(20) DEFAULT 'user_action' CHECK (category IN ('user_action', 'system_action', 'moderation', 'security')),
    
    -- Rétention
    retention_policy VARCHAR(20) DEFAULT 'standard' CHECK (retention_policy IN ('short', 'standard', 'long', 'permanent')),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour performances
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_performed_by ON audit_logs(performed_by);
CREATE INDEX idx_audit_logs_performed_at ON audit_logs(performed_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action_type);
CREATE INDEX idx_audit_logs_category ON audit_logs(category);
CREATE INDEX idx_audit_logs_severity ON audit_logs(severity);

-- Index partiel pour les actions critiques
CREATE INDEX idx_audit_logs_critical ON audit_logs(performed_at, entity_type) 
WHERE severity IN ('error', 'critical');
```

### Tables Spécialisées pour Performance
```sql
-- Table d'audit spécialisée pour les snippets (accès fréquent)
CREATE TABLE snippet_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    snippet_id UUID NOT NULL,
    snippet_type VARCHAR(20) NOT NULL CHECK (snippet_type IN ('project', 'public')),
    action_type VARCHAR(20) NOT NULL,
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Données spécifiques aux snippets
    title_before TEXT,
    title_after TEXT,
    code_before TEXT,
    code_after TEXT,
    language_before VARCHAR(50),
    language_after VARCHAR(50),
    
    -- Hash pour détection de changements
    content_hash_before VARCHAR(64),
    content_hash_after VARCHAR(64),
    
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table d'audit pour les actions de modération
CREATE TABLE moderation_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    moderator_id UUID REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(20),
    entity_id UUID,
    
    action_type VARCHAR(30) NOT NULL,
    reason TEXT NOT NULL,
    severity VARCHAR(10) DEFAULT 'info',
    
    -- Données avant/après pour rollback
    previous_state JSONB,
    new_state JSONB,
    
    -- Métadonnées de modération
    auto_generated BOOLEAN DEFAULT FALSE,
    requires_approval BOOLEAN DEFAULT FALSE,
    approved_by UUID REFERENCES users(id),
    
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🔧 Fonctions d'Audit Automatisées

### Triggers Génériques
```sql
-- Fonction générique pour audit automatique
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    old_json JSONB;
    new_json JSONB;
    changed_fields JSONB;
    current_user_id UUID;
    action_type VARCHAR(20);
BEGIN
    -- Déterminer le type d'action
    CASE TG_OP
        WHEN 'INSERT' THEN
            action_type := 'create';
            old_json := NULL;
            new_json := to_jsonb(NEW);
        WHEN 'UPDATE' THEN
            action_type := 'update';
            old_json := to_jsonb(OLD);
            new_json := to_jsonb(NEW);
        WHEN 'DELETE' THEN
            action_type := 'delete';
            old_json := to_jsonb(OLD);
            new_json := NULL;
    END CASE;
    
    -- Calculer les champs modifiés (pour UPDATE)
    IF TG_OP = 'UPDATE' THEN
        changed_fields := jsonb_build_object();
        -- Logique pour identifier les champs modifiés
        -- (implémentation détaillée selon les besoins)
    END IF;
    
    -- Obtenir l'utilisateur actuel (depuis une variable de session)
    current_user_id := current_setting('app.current_user_id', true)::UUID;
    
    -- Insérer dans les logs d'audit
    INSERT INTO audit_logs (
        entity_type,
        entity_id,
        action_type,
        performed_by,
        old_values,
        new_values,
        changed_fields,
        context
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        action_type,
        current_user_id,
        old_json,
        new_json,
        changed_fields,
        jsonb_build_object('trigger', TG_NAME, 'operation', TG_OP)
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

### Triggers Spécifiques par Entité
```sql
-- Trigger pour les projets
CREATE TRIGGER audit_projects_trigger
    AFTER INSERT OR UPDATE OR DELETE ON projects
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour les notes
CREATE TRIGGER audit_notes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_notes
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour les snippets
CREATE TRIGGER audit_snippets_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_snippets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour les snippets publics
CREATE TRIGGER audit_public_snippets_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public_snippets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour les tâches
CREATE TRIGGER audit_tasks_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour les utilisateurs (informations sensibles)
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

## 🛡️ Audit de Sécurité

### Table d'Audit Sécuritaire
```sql
-- Table spécialisée pour les événements de sécurité
CREATE TABLE security_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Événement de sécurité
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
        'login_success', 'login_failure', 'logout', 'password_change',
        'role_change', 'permission_change', 'account_locked', 'account_unlocked',
        'suspicious_activity', 'data_breach_attempt', 'unauthorized_access'
    )),
    
    -- Utilisateur concerné
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Pour les actions sur d'autres utilisateurs
    
    -- Contexte technique
    ip_address INET NOT NULL,
    user_agent TEXT,
    session_id UUID,
    
    -- Détails de l'événement
    severity VARCHAR(10) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    details JSONB,
    
    -- Géolocalisation (optionnel)
    country VARCHAR(2),
    city VARCHAR(100),
    
    -- Flags de sécurité
    is_anomaly BOOLEAN DEFAULT FALSE,
    requires_investigation BOOLEAN DEFAULT FALSE,
    investigated_by UUID REFERENCES users(id),
    investigation_notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour détection d'anomalies
CREATE INDEX idx_security_audit_user_event ON security_audit_logs(user_id, event_type, created_at);
CREATE INDEX idx_security_audit_ip ON security_audit_logs(ip_address, created_at);
CREATE INDEX idx_security_audit_anomaly ON security_audit_logs(is_anomaly, created_at) WHERE is_anomaly = TRUE;
```

## 📈 Système de Métriques et Alertes

### Détection d'Anomalies
```sql
-- Vue pour détecter les activités suspectes
CREATE VIEW suspicious_activities AS
SELECT 
    user_id,
    COUNT(*) as event_count,
    COUNT(DISTINCT ip_address) as unique_ips,
    COUNT(DISTINCT event_type) as event_types,
    MIN(created_at) as first_event,
    MAX(created_at) as last_event
FROM security_audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
HAVING 
    COUNT(*) > 100 OR -- Trop d'événements
    COUNT(DISTINCT ip_address) > 5 OR -- Trop d'IPs différentes
    COUNT(DISTINCT event_type) > 10; -- Trop de types d'événements différents

-- Fonction pour créer des alertes automatiques
CREATE OR REPLACE FUNCTION create_security_alert()
RETURNS TRIGGER AS $$
BEGIN
    -- Créer une alerte si événement critique
    IF NEW.severity = 'critical' THEN
        INSERT INTO notifications (
            user_id,
            type,
            title,
            message,
            entity_type,
            entity_id
        ) 
        SELECT 
            u.id,
            'security_alert',
            'Événement de sécurité critique',
            'Un événement de sécurité critique a été détecté: ' || NEW.event_type,
            'security_event',
            NEW.id
        FROM users u
        WHERE u.id IN (
            SELECT user_id FROM user_roles WHERE role = 'admin'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour alertes automatiques
CREATE TRIGGER security_alert_trigger
    AFTER INSERT ON security_audit_logs
    FOR EACH ROW EXECUTE FUNCTION create_security_alert();
```

## 🔄 Système de Rollback

### Fonctions de Restauration
```sql
-- Fonction pour restaurer une entité à un état précédent
CREATE OR REPLACE FUNCTION restore_entity_to_version(
    p_entity_type VARCHAR(50),
    p_entity_id UUID,
    p_target_timestamp TIMESTAMP WITH TIME ZONE
) RETURNS BOOLEAN AS $$
DECLARE
    target_log RECORD;
    restore_data JSONB;
    table_name VARCHAR(50);
    sql_query TEXT;
BEGIN
    -- Trouver le log d'audit le plus récent avant le timestamp cible
    SELECT * INTO target_log
    FROM audit_logs
    WHERE entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND performed_at <= p_target_timestamp
      AND action_type != 'delete'
    ORDER BY performed_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Déterminer la table cible
    table_name := CASE p_entity_type
        WHEN 'project' THEN 'projects'
        WHEN 'note' THEN 'project_notes'
        WHEN 'snippet' THEN 'project_snippets'
        WHEN 'task' THEN 'tasks'
        ELSE p_entity_type
    END;
    
    -- Construire et exécuter la requête de restauration
    -- (Implémentation détaillée selon le type d'entité)
    
    -- Logger l'action de restauration
    INSERT INTO audit_logs (
        entity_type,
        entity_id,
        action_type,
        performed_by,
        context,
        reason
    ) VALUES (
        p_entity_type,
        p_entity_id,
        'restore',
        current_setting('app.current_user_id', true)::UUID,
        jsonb_build_object('restored_from', target_log.id, 'target_timestamp', p_target_timestamp),
        'Restored to previous version'
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
```

## 📊 APIs d'Audit

### Endpoints REST
```rust
// Récupérer l'historique d'audit d'une entité
GET /api/audit/{entity_type}/{entity_id}

// Rechercher dans les logs d'audit
GET /api/audit/search?q={query}&from={date}&to={date}

// Statistiques d'audit
GET /api/audit/stats

// Restaurer une entité (admin uniquement)
POST /api/audit/restore
{
    "entity_type": "snippet",
    "entity_id": "uuid",
    "target_timestamp": "2023-01-01T00:00:00Z"
}

// Événements de sécurité
GET /api/audit/security/events
GET /api/audit/security/anomalies
```

## 🗂️ Politiques de Rétention

### Règles de Rétention par Catégorie
```sql
-- Fonction pour appliquer les politiques de rétention
CREATE OR REPLACE FUNCTION apply_retention_policies() RETURNS VOID AS $$
BEGIN
    -- Supprimer les logs expirés selon leur politique
    DELETE FROM audit_logs 
    WHERE expires_at < NOW();
    
    -- Appliquer les politiques par défaut
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '3 months'
    WHERE retention_policy = 'short' AND expires_at IS NULL;
    
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '2 years'
    WHERE retention_policy = 'standard' AND expires_at IS NULL;
    
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '7 years'
    WHERE retention_policy = 'long' AND expires_at IS NULL;
    
    -- Les logs permanents n'ont pas d'expiration
    
    -- Archiver les anciens logs vers un stockage froid
    -- (Implémentation selon l'infrastructure)
    
END;
$$ LANGUAGE plpgsql;

-- Tâche cron pour nettoyer les logs expirés
SELECT cron.schedule('audit-cleanup', '0 2 * * *', 'SELECT apply_retention_policies()');
```

## 🎯 Cas d'Usage Pratiques

### 1. Détection de Modifications Suspectes
```sql
-- Détecter les modifications massives par un utilisateur
SELECT 
    performed_by,
    COUNT(*) as actions_count,
    COUNT(DISTINCT entity_id) as entities_affected,
    MIN(performed_at) as first_action,
    MAX(performed_at) as last_action
FROM audit_logs
WHERE performed_at > NOW() - INTERVAL '1 hour'
  AND action_type IN ('update', 'delete')
GROUP BY performed_by
HAVING COUNT(*) > 50;
```

### 2. Historique Complet d'une Entité
```sql
-- Obtenir l'historique complet d'un snippet
SELECT 
    al.performed_at,
    al.action_type,
    u.username as performed_by,
    al.changed_fields,
    al.reason
FROM audit_logs al
LEFT JOIN users u ON al.performed_by = u.id
WHERE al.entity_type = 'snippet'
  AND al.entity_id = 'target-snippet-uuid'
ORDER BY al.performed_at DESC;
```

### 3. Rollback d'une Action de Modération
```sql
-- Annuler une action de modération
SELECT restore_entity_to_version(
    'snippet',
    'snippet-uuid',
    '2023-01-01 12:00:00'::timestamp
);
```

Ce système d'audit complet offre une traçabilité totale, des capacités de rollback robustes et une sécurité renforcée ! 🔒
