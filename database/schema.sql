-- =============================================================================
-- ETTU Backend Database Schema
-- Architecture multi-utilisateurs avec partage et permissions
-- =============================================================================

-- Extensions PostgreSQL nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext"; -- Pour les emails case-insensitive

-- =============================================================================
-- TABLES UTILISATEURS & AUTHENTIFICATION
-- =============================================================================

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
    
    -- Statistiques publiques
    public_snippets_count INT DEFAULT 0,
    public_projects_count INT DEFAULT 0,
    contributions_count INT DEFAULT 0,
    
    -- Migration
    migrated_from_anonymous_id UUID, -- Référence vers l'ancien ID invité
    migrated_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contraintes pour garantir la cohérence
    CONSTRAINT users_email_required_for_registered 
        CHECK (user_type = 'guest' OR email IS NOT NULL),
    CONSTRAINT users_password_required_for_registered 
        CHECK (user_type = 'guest' OR password_hash IS NOT NULL),
    CONSTRAINT users_anonymous_id_required_for_guest 
        CHECK (user_type != 'guest' OR anonymous_id IS NOT NULL)
);

-- Table des sessions utilisateurs (hybride)
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

-- Permissions par défaut selon le type d'utilisateur
CREATE TABLE default_permissions (
    user_type VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (user_type, permission)
);

-- =============================================================================
-- TABLES PROJETS & PERMISSIONS
-- =============================================================================

-- Table des projets
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7) NOT NULL, -- Couleur hex
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'archived')),
    
    -- Propriétaire du projet
    owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Visibilité et partage
    visibility VARCHAR(10) NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'team', 'public')),
    is_template BOOLEAN DEFAULT FALSE,
    template_category VARCHAR(50),
    
    -- Statistiques (mises à jour via triggers)
    total_notes INT DEFAULT 0,
    total_snippets INT DEFAULT 0,
    total_tasks INT DEFAULT 0,
    completed_tasks INT DEFAULT 0,
    members_count INT DEFAULT 1,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Configuration
    settings JSONB DEFAULT '{
        "allowPublicSharing": false,
        "defaultNoteType": "brief",
        "defaultSnippetLanguage": "javascript",
        "enableComments": true,
        "enableTasks": true,
        "enableDiscussions": true
    }',
    
    -- Métadonnées
    technologies JSONB DEFAULT '[]',
    repository VARCHAR(255),
    documentation VARCHAR(255),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des permissions sur les projets
CREATE TABLE project_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'admin', 'editor', 'viewer')),
    
    -- Permissions spécifiques
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
    can_delete_tasks BOOLEAN DEFAULT FALSE,
    
    invited_by UUID REFERENCES users(id),
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(project_id, user_id)
);

-- =============================================================================
-- TABLES CONTENU
-- =============================================================================

-- Table des notes de projet
CREATE TABLE project_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'brief' CHECK (type IN ('brief', 'analysis', 'documentation', 'research', 'meeting', 'idea')),
    tags JSONB DEFAULT '[]',
    
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Métadonnées d'organisation
    folder VARCHAR(255),
    is_pinned BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- Collaboration
    last_edited_by UUID REFERENCES users(id),
    version INT DEFAULT 1,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des snippets de projet
CREATE TABLE project_snippets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    code TEXT NOT NULL,
    language VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'function' CHECK (type IN ('function', 'component', 'hook', 'utility', 'config', 'template')),
    tags JSONB DEFAULT '[]',
    
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Métadonnées d'organisation
    folder VARCHAR(255),
    is_pinned BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- Publication publique
    is_public BOOLEAN DEFAULT FALSE,
    public_snippet_id UUID REFERENCES public_snippets(id),
    
    -- Informations techniques
    dependencies JSONB DEFAULT '[]',
    usage_example TEXT,
    
    -- Collaboration
    last_edited_by UUID REFERENCES users(id),
    version INT DEFAULT 1,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- BANQUE DE SNIPPETS PUBLIQUE
-- =============================================================================

-- Table des snippets publics
CREATE TABLE public_snippets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    code TEXT NOT NULL,
    language VARCHAR(50) NOT NULL,
    tags JSONB DEFAULT '[]',
    
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Métadonnées
    category VARCHAR(50),
    difficulty VARCHAR(10) CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    
    -- Origine du snippet
    source_type VARCHAR(20) DEFAULT 'original' CHECK (source_type IN ('original', 'from_project', 'fork')),
    source_project_id UUID REFERENCES projects(id),
    source_snippet_id UUID REFERENCES project_snippets(id),
    
    -- Statistiques d'engagement
    views_count INT DEFAULT 0,
    likes_count INT DEFAULT 0,
    forks_count INT DEFAULT 0,
    downloads_count INT DEFAULT 0,
    
    -- Trending score (mis à jour périodiquement)
    trending_score FLOAT DEFAULT 0,
    
    -- Modération
    moderation_status VARCHAR(20) DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'flagged')),
    is_featured BOOLEAN DEFAULT FALSE,
    moderated_by UUID REFERENCES users(id),
    moderated_at TIMESTAMP WITH TIME ZONE,
    moderation_note TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des likes sur les snippets publics
CREATE TABLE public_snippet_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    snippet_id UUID REFERENCES public_snippets(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(snippet_id, user_id)
);

-- Table des forks de snippets publics
CREATE TABLE public_snippet_forks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    original_snippet_id UUID REFERENCES public_snippets(id) ON DELETE CASCADE,
    forked_snippet_id UUID REFERENCES public_snippets(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- SYSTÈME DE TÂCHES
-- =============================================================================

-- Table des tâches
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(20) NOT NULL DEFAULT 'feature' CHECK (type IN ('feature', 'bug', 'refactor', 'documentation', 'test', 'idea')),
    priority VARCHAR(10) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) NOT NULL DEFAULT 'backlog' CHECK (status IN ('backlog', 'in-progress', 'testing', 'done')),
    tags JSONB DEFAULT '[]',
    
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    assignee_id UUID REFERENCES users(id),
    
    estimated_time INT, -- en minutes
    actual_time INT, -- en minutes
    due_date TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    order_position INT DEFAULT 0,
    
    -- Références
    related_notes JSONB DEFAULT '[]',
    related_snippets JSONB DEFAULT '[]',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des éléments de checklist
CREATE TABLE task_checklist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    order_position INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- SYSTÈME DE MESSAGERIE
-- =============================================================================

-- Table des conversations
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('direct', 'group', 'project')),
    name VARCHAR(255), -- Pour les groupes
    description TEXT,
    
    -- Référence projet si conversation liée à un projet
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    
    -- Métadonnées
    is_archived BOOLEAN DEFAULT FALSE,
    last_message_at TIMESTAMP WITH TIME ZONE,
    
    created_by UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des participants aux conversations
CREATE TABLE conversation_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Permissions
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    can_add_members BOOLEAN DEFAULT FALSE,
    can_remove_members BOOLEAN DEFAULT FALSE,
    
    -- Statut
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    left_at TIMESTAMP WITH TIME ZONE,
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(conversation_id, user_id)
);

-- Table des messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    content TEXT NOT NULL,
    type VARCHAR(20) DEFAULT 'text' CHECK (type IN ('text', 'image', 'file', 'code', 'system')),
    
    -- Métadonnées
    attachments JSONB DEFAULT '[]',
    mentions JSONB DEFAULT '[]', -- User IDs mentionnés
    
    -- Réponses
    reply_to UUID REFERENCES messages(id) ON DELETE SET NULL,
    
    -- Édition
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE,
    
    -- Modération
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES users(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des réactions aux messages
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(message_id, user_id, emoji)
);

-- =============================================================================
-- SYSTÈME DE NOTIFICATIONS
-- =============================================================================

-- Table des notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Données contextuelles
    entity_type VARCHAR(50), -- 'project', 'task', 'message', etc.
    entity_id UUID,
    
    -- Statut
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- SYSTÈME DE COMMENTAIRES
-- =============================================================================

-- Table des commentaires (générique pour notes, snippets, tâches)
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Référence à l'entité commentée
    entity_type VARCHAR(50) NOT NULL, -- 'note', 'snippet', 'task', 'public_snippet'
    entity_id UUID NOT NULL,
    
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    
    -- Réponses
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    
    -- Métadonnées
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- SYSTÈME D'AUDIT COMPLET
-- =============================================================================

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

-- Table d'audit spécialisée pour les événements de sécurité
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
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
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

-- =============================================================================
-- SYSTÈME DE VERSIONING
-- =============================================================================

-- Table des versions de notes
CREATE TABLE note_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    note_id UUID REFERENCES project_notes(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    change_summary TEXT, -- Résumé des changements
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Métadonnées de version
    is_major BOOLEAN DEFAULT FALSE, -- Version majeure vs mineure
    parent_version_id UUID REFERENCES note_versions(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(note_id, version_number)
);

-- Table des versions de snippets
CREATE TABLE snippet_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    snippet_id UUID REFERENCES project_snippets(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    code TEXT NOT NULL,
    language VARCHAR(50) NOT NULL,
    change_summary TEXT,
    author_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Métadonnées de version
    is_major BOOLEAN DEFAULT FALSE,
    parent_version_id UUID REFERENCES snippet_versions(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(snippet_id, version_number)
);

-- Table des relations de fork
CREATE TABLE snippet_fork_relations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    original_snippet_id UUID NOT NULL, -- Snippet original (public)
    fork_snippet_id UUID NOT NULL, -- Fork (public ou project)
    fork_type VARCHAR(20) NOT NULL CHECK (fork_type IN ('public', 'project')),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE, -- NULL si fork public
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des rôles globaux
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'moderator', 'reviewer', 'user', 'restricted')),
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE, -- NULL = permanent
    
    UNIQUE(user_id, role)
);

-- Table des permissions détaillées
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role VARCHAR(20) NOT NULL,
    permission VARCHAR(50) NOT NULL,
    is_granted BOOLEAN DEFAULT TRUE,
    
    UNIQUE(role, permission)
);

-- Table des actions de modération (audit trail)
CREATE TABLE moderation_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    moderator_id UUID REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(20) CHECK (entity_type IN ('snippet', 'comment', 'user')),
    entity_id UUID,
    action_type VARCHAR(30) NOT NULL CHECK (action_type IN ('warn', 'restrict', 'ban', 'delete', 'edit', 'feature', 'approve', 'reject')),
    reason TEXT NOT NULL,
    details JSONB,
    expires_at TIMESTAMP WITH TIME ZONE, -- Pour les restrictions temporaires
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table de réputation des utilisateurs
CREATE TABLE user_reputation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reputation_score INT DEFAULT 0,
    positive_actions INT DEFAULT 0,
    negative_actions INT DEFAULT 0,
    
    -- Détails des facteurs
    snippet_likes INT DEFAULT 0,
    snippet_forks INT DEFAULT 0,
    valid_reports INT DEFAULT 0,
    invalid_reports INT DEFAULT 0,
    warnings_received INT DEFAULT 0,
    content_removed INT DEFAULT 0,
    
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- Table des signalements
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('snippet', 'user', 'comment', 'message')),
    entity_id UUID NOT NULL,
    reason VARCHAR(50) NOT NULL CHECK (reason IN ('spam', 'inappropriate', 'copyright', 'security', 'other')),
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
    
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    resolution_note TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- INDEXES POUR AUDIT ET SÉCURITÉ
-- =============================================================================

-- Audit logs
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_performed_by ON audit_logs(performed_by);
CREATE INDEX idx_audit_logs_performed_at ON audit_logs(performed_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action_type);
CREATE INDEX idx_audit_logs_category ON audit_logs(category);
CREATE INDEX idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX idx_audit_logs_critical ON audit_logs(performed_at, entity_type) WHERE severity IN ('error', 'critical');

-- Security audit logs
CREATE INDEX idx_security_audit_user_event ON security_audit_logs(user_id, event_type, created_at);
CREATE INDEX idx_security_audit_ip ON security_audit_logs(ip_address, created_at);
CREATE INDEX idx_security_audit_anomaly ON security_audit_logs(is_anomaly, created_at) WHERE is_anomaly = TRUE;
CREATE INDEX idx_security_audit_severity ON security_audit_logs(severity, created_at);

-- =============================================================================
-- TRIGGERS POUR AUDIT AUTOMATIQUE
-- =============================================================================

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
        -- Identifier les champs modifiés
        IF old_json IS DISTINCT FROM new_json THEN
            changed_fields := jsonb_build_object(
                'modified_fields', jsonb_object_keys(old_json - new_json || new_json - old_json)
            );
        END IF;
    END IF;
    
    -- Obtenir l'utilisateur actuel (depuis une variable de session)
    BEGIN
        current_user_id := current_setting('app.current_user_id', false)::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            current_user_id := NULL;
    END;
    
    -- Insérer dans les logs d'audit
    INSERT INTO audit_logs (
        entity_type,
        entity_id,
        action_type,
        performed_by,
        old_values,
        new_values,
        changed_fields,
        context,
        category
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        action_type,
        current_user_id,
        old_json,
        new_json,
        changed_fields,
        jsonb_build_object('trigger', TG_NAME, 'operation', TG_OP),
        'user_action'
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créer des alertes de sécurité automatiques
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

-- Appliquer les triggers d'audit
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_projects_trigger
    AFTER INSERT OR UPDATE OR DELETE ON projects
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_notes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_notes
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_snippets_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_snippets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_public_snippets_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public_snippets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_tasks_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_permissions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON project_permissions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_roles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger pour alertes de sécurité
CREATE TRIGGER security_alert_trigger
    AFTER INSERT ON security_audit_logs
    FOR EACH ROW EXECUTE FUNCTION create_security_alert();

-- =============================================================================
-- FONCTIONS UTILITAIRES POUR AUDIT
-- =============================================================================

-- Fonction pour obtenir l'historique d'audit d'une entité
CREATE OR REPLACE FUNCTION get_entity_audit_history(
    p_entity_type VARCHAR(50),
    p_entity_id UUID,
    p_limit INT DEFAULT 50
) RETURNS TABLE (
    id UUID,
    action_type VARCHAR(20),
    performed_by UUID,
    performed_at TIMESTAMP WITH TIME ZONE,
    old_values JSONB,
    new_values JSONB,
    changed_fields JSONB,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.id,
        al.action_type,
        al.performed_by,
        al.performed_at,
        al.old_values,
        al.new_values,
        al.changed_fields,
        al.reason
    FROM audit_logs al
    WHERE al.entity_type = p_entity_type
      AND al.entity_id = p_entity_id
    ORDER BY al.performed_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour restaurer une entité à un état précédent
CREATE OR REPLACE FUNCTION restore_entity_to_version(
    p_entity_type VARCHAR(50),
    p_entity_id UUID,
    p_target_timestamp TIMESTAMP WITH TIME ZONE
) RETURNS BOOLEAN AS $$
DECLARE
    target_log RECORD;
    current_user_id UUID;
    table_name VARCHAR(50);
BEGIN
    -- Obtenir l'utilisateur actuel
    BEGIN
        current_user_id := current_setting('app.current_user_id', false)::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE; -- Pas d'utilisateur authentifié
    END;
    
    -- Trouver le log d'audit le plus récent avant le timestamp cible
    SELECT * INTO target_log
    FROM audit_logs
    WHERE entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND performed_at <= p_target_timestamp
      AND action_type != 'delete'
      AND old_values IS NOT NULL OR new_values IS NOT NULL
    ORDER BY performed_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Déterminer la table cible
    table_name := CASE p_entity_type
        WHEN 'projects' THEN 'projects'
        WHEN 'project_notes' THEN 'project_notes'
        WHEN 'project_snippets' THEN 'project_snippets'
        WHEN 'public_snippets' THEN 'public_snippets'
        WHEN 'tasks' THEN 'tasks'
        ELSE p_entity_type
    END;
    
    -- Logger l'action de restauration
    INSERT INTO audit_logs (
        entity_type,
        entity_id,
        action_type,
        performed_by,
        context,
        reason,
        category
    ) VALUES (
        p_entity_type,
        p_entity_id,
        'restore',
        current_user_id,
        jsonb_build_object(
            'restored_from', target_log.id, 
            'target_timestamp', p_target_timestamp,
            'restore_method', 'audit_rollback'
        ),
        'Restored to previous version via audit system',
        'moderation'
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour appliquer les politiques de rétention
CREATE OR REPLACE FUNCTION apply_retention_policies() RETURNS VOID AS $$
BEGIN
    -- Supprimer les logs expirés selon leur politique
    DELETE FROM audit_logs 
    WHERE expires_at < NOW();
    
    -- Appliquer les politiques par défaut si pas d'expiration définie
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '3 months'
    WHERE retention_policy = 'short' AND expires_at IS NULL;
    
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '2 years'
    WHERE retention_policy = 'standard' AND expires_at IS NULL;
    
    UPDATE audit_logs SET expires_at = NOW() + INTERVAL '7 years'
    WHERE retention_policy = 'long' AND expires_at IS NULL;
    
    -- Les logs permanents n'ont pas d'expiration (expires_at reste NULL)
    
    -- Nettoyer les logs de sécurité anciens (garde 1 an par défaut)
    DELETE FROM security_audit_logs 
    WHERE created_at < NOW() - INTERVAL '1 year'
      AND severity NOT IN ('high', 'critical');
    
    -- Garder les événements critiques plus longtemps (5 ans)
    DELETE FROM security_audit_logs 
    WHERE created_at < NOW() - INTERVAL '5 years'
      AND severity IN ('high', 'critical');
END;
$$ LANGUAGE plpgsql;

-- Vue pour détecter les activités suspectes
CREATE VIEW suspicious_activities AS
SELECT 
    user_id,
    COUNT(*) as event_count,
    COUNT(DISTINCT ip_address) as unique_ips,
    COUNT(DISTINCT event_type) as event_types,
    MIN(created_at) as first_event,
    MAX(created_at) as last_event,
    CASE 
        WHEN COUNT(*) > 100 THEN 'high_frequency'
        WHEN COUNT(DISTINCT ip_address) > 5 THEN 'multiple_ips'
        WHEN COUNT(DISTINCT event_type) > 10 THEN 'diverse_actions'
        ELSE 'normal'
    END as anomaly_type
FROM security_audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
HAVING 
    COUNT(*) > 50 OR 
    COUNT(DISTINCT ip_address) > 3 OR 
    COUNT(DISTINCT event_type) > 8;

-- =============================================================================
-- INDEXES POUR VERSIONING ET MODÉRATION
-- =============================================================================

-- Note versions
CREATE INDEX idx_note_versions_note_id ON note_versions(note_id);
CREATE INDEX idx_note_versions_version_number ON note_versions(note_id, version_number);

-- Snippet versions
CREATE INDEX idx_snippet_versions_snippet_id ON snippet_versions(snippet_id);
CREATE INDEX idx_snippet_versions_version_number ON snippet_versions(snippet_id, version_number);

-- Fork relations
CREATE INDEX idx_fork_relations_original ON snippet_fork_relations(original_snippet_id);
CREATE INDEX idx_fork_relations_fork ON snippet_fork_relations(fork_snippet_id);
CREATE INDEX idx_fork_relations_user ON snippet_fork_relations(user_id);

-- User roles
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role);

-- Reports
CREATE INDEX idx_reports_entity ON reports(entity_type, entity_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_reporter ON reports(reporter_id);

-- Public snippets trending
CREATE INDEX idx_public_snippets_trending ON public_snippets(trending_score DESC);
CREATE INDEX idx_public_snippets_moderation ON public_snippets(moderation_status);

-- =============================================================================
-- TRIGGERS POUR VERSIONING
-- =============================================================================

-- Fonction pour créer une version de note automatiquement
CREATE OR REPLACE FUNCTION create_note_version()
RETURNS TRIGGER AS $$
BEGIN
    -- Créer une nouvelle version à chaque UPDATE significatif
    IF TG_OP = 'UPDATE' AND (OLD.content != NEW.content OR OLD.title != NEW.title) THEN
        INSERT INTO note_versions (
            note_id, version_number, title, content, author_id
        ) VALUES (
            NEW.id,
            COALESCE((SELECT MAX(version_number) FROM note_versions WHERE note_id = NEW.id), 0) + 1,
            NEW.title,
            NEW.content,
            NEW.last_edited_by
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créer une version de snippet automatiquement
CREATE OR REPLACE FUNCTION create_snippet_version()
RETURNS TRIGGER AS $$
BEGIN
    -- Créer une nouvelle version à chaque UPDATE significatif
    IF TG_OP = 'UPDATE' AND (OLD.code != NEW.code OR OLD.title != NEW.title) THEN
        INSERT INTO snippet_versions (
            snippet_id, version_number, title, description, code, language, author_id
        ) VALUES (
            NEW.id,
            COALESCE((SELECT MAX(version_number) FROM snippet_versions WHERE snippet_id = NEW.id), 0) + 1,
            NEW.title,
            NEW.description,
            NEW.code,
            NEW.language,
            NEW.last_edited_by
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer les triggers de versioning
CREATE TRIGGER trigger_note_versioning
    AFTER UPDATE ON project_notes
    FOR EACH ROW EXECUTE FUNCTION create_note_version();

CREATE TRIGGER trigger_snippet_versioning
    AFTER UPDATE ON project_snippets
    FOR EACH ROW EXECUTE FUNCTION create_snippet_version();

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

-- Fonction pour vérifier les permissions d'un utilisateur (hybride)
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
    FROM users
    WHERE id = p_user_id;
    
    IF user_type_val IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Vérifier les permissions par défaut selon le type
    SELECT is_granted INTO has_permission
    FROM default_permissions
    WHERE user_type = user_type_val AND permission = p_permission;
    
    -- Si pas de permission spécifique, vérifier les rôles (pour les comptes)
    IF has_permission IS NULL AND user_type_val IN ('registered', 'migrated') THEN
        -- Logique des rôles pour les utilisateurs enregistrés
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

-- =============================================================================
-- DONNÉES INITIALES POUR PERMISSIONS HYBRIDES
-- =============================================================================

-- Permissions pour les invités
INSERT INTO default_permissions (user_type, permission, is_granted) VALUES
('guest', 'create_projects', TRUE),
('guest', 'edit_own_projects', TRUE),
('guest', 'delete_own_projects', TRUE),
('guest', 'create_notes', TRUE),
('guest', 'edit_own_notes', TRUE),
('guest', 'delete_own_notes', TRUE),
('guest', 'create_snippets', TRUE),
('guest', 'edit_own_snippets', TRUE),
('guest', 'delete_own_snippets', TRUE),
('guest', 'create_tasks', TRUE),
('guest', 'edit_own_tasks', TRUE),
('guest', 'delete_own_tasks', TRUE),
('guest', 'export_data', TRUE),
('guest', 'view_public_snippets', TRUE);

-- Permissions pour les utilisateurs enregistrés (héritent des permissions invité)
INSERT INTO default_permissions (user_type, permission, is_granted) VALUES
('registered', 'create_projects', TRUE),
('registered', 'edit_own_projects', TRUE),
('registered', 'delete_own_projects', TRUE),
('registered', 'create_notes', TRUE),
('registered', 'edit_own_notes', TRUE),
('registered', 'delete_own_notes', TRUE),
('registered', 'create_snippets', TRUE),
('registered', 'edit_own_snippets', TRUE),
('registered', 'delete_own_snippets', TRUE),
('registered', 'create_tasks', TRUE),
('registered', 'edit_own_tasks', TRUE),
('registered', 'delete_own_tasks', TRUE),
('registered', 'export_data', TRUE),
('registered', 'view_public_snippets', TRUE),
-- Permissions supplémentaires pour les comptes
('registered', 'sync_data', TRUE),
('registered', 'share_projects', TRUE),
('registered', 'collaborate', TRUE),
('registered', 'access_history', TRUE),
('registered', 'publish_snippets', TRUE),
('registered', 'fork_snippets', TRUE),
('registered', 'like_snippets', TRUE),
('registered', 'comment', TRUE),
('registered', 'report_content', TRUE);

-- Permissions pour les utilisateurs migrés (identiques aux enregistrés)
INSERT INTO default_permissions (user_type, permission, is_granted) 
SELECT 'migrated', permission, is_granted 
FROM default_permissions 
WHERE user_type = 'registered';

-- =============================================================================
-- INDEXES POUR SYSTÈME HYBRIDE
-- =============================================================================

-- Users hybrides
CREATE INDEX idx_users_anonymous_id ON users(anonymous_id) WHERE anonymous_id IS NOT NULL;
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_session_expires ON users(session_expires_at) WHERE session_expires_at IS NOT NULL;
CREATE INDEX idx_users_migrated_from ON users(migrated_from_anonymous_id) WHERE migrated_from_anonymous_id IS NOT NULL;

-- Sessions hybrides
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_type ON user_sessions(session_type);
CREATE INDEX idx_user_sessions_persistent ON user_sessions(is_persistent) WHERE is_persistent = TRUE;

-- Migrations
CREATE INDEX idx_user_migrations_source ON user_migrations(source_anonymous_id);
CREATE INDEX idx_user_migrations_destination ON user_migrations(destination_user_id);
CREATE INDEX idx_user_migrations_status ON user_migrations(migration_status);

-- =============================================================================
-- TÂCHES CRON POUR NETTOYAGE
-- =============================================================================

-- Nettoyage quotidien des données expirées
-- SELECT cron.schedule('cleanup-guest-data', '0 3 * * *', 'SELECT cleanup_expired_guest_data()');

-- =============================================================================
-- INDEXES POUR PERFORMANCES
-- =============================================================================

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Sessions
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);

-- Projects
CREATE INDEX idx_projects_owner_id ON projects(owner_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_visibility ON projects(visibility);
CREATE INDEX idx_projects_is_template ON projects(is_template);

-- Project permissions
CREATE INDEX idx_project_permissions_project_id ON project_permissions(project_id);
CREATE INDEX idx_project_permissions_user_id ON project_permissions(user_id);
CREATE INDEX idx_project_permissions_role ON project_permissions(role);

-- Project notes
CREATE INDEX idx_project_notes_project_id ON project_notes(project_id);
CREATE INDEX idx_project_notes_author_id ON project_notes(author_id);
CREATE INDEX idx_project_notes_type ON project_notes(type);
CREATE INDEX idx_project_notes_tags ON project_notes USING GIN(tags);

-- Project snippets
CREATE INDEX idx_project_snippets_project_id ON project_snippets(project_id);
CREATE INDEX idx_project_snippets_author_id ON project_snippets(author_id);
CREATE INDEX idx_project_snippets_language ON project_snippets(language);
CREATE INDEX idx_project_snippets_tags ON project_snippets USING GIN(tags);

-- Public snippets
CREATE INDEX idx_public_snippets_author_id ON public_snippets(author_id);
CREATE INDEX idx_public_snippets_language ON public_snippets(language);
CREATE INDEX idx_public_snippets_category ON public_snippets(category);
CREATE INDEX idx_public_snippets_tags ON public_snippets USING GIN(tags);
CREATE INDEX idx_public_snippets_is_approved ON public_snippets(is_approved);
CREATE INDEX idx_public_snippets_is_featured ON public_snippets(is_featured);
CREATE INDEX idx_public_snippets_likes_count ON public_snippets(likes_count);

-- Tasks
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_author_id ON tasks(author_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

-- Messages
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_messages_reply_to ON messages(reply_to);

-- Conversations
CREATE INDEX idx_conversations_project_id ON conversations(project_id);
CREATE INDEX idx_conversations_type ON conversations(type);
CREATE INDEX idx_conversation_participants_user_id ON conversation_participants(user_id);

-- Notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Comments
CREATE INDEX idx_comments_entity_type_id ON comments(entity_type, entity_id);
CREATE INDEX idx_comments_author_id ON comments(author_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);

-- =============================================================================
-- TRIGGERS POUR STATISTIQUES
-- =============================================================================

-- Fonction pour mettre à jour les statistiques des projets
CREATE OR REPLACE FUNCTION update_project_stats()
RETURNS TRIGGER AS $$
DECLARE
    proj_id UUID;
BEGIN
    -- Déterminer l'ID du projet
    proj_id := COALESCE(NEW.project_id, OLD.project_id);
    
    -- Mettre à jour les statistiques
    UPDATE projects SET
        total_notes = (SELECT COUNT(*) FROM project_notes WHERE project_id = proj_id),
        total_snippets = (SELECT COUNT(*) FROM project_snippets WHERE project_id = proj_id),
        total_tasks = (SELECT COUNT(*) FROM tasks WHERE project_id = proj_id),
        completed_tasks = (SELECT COUNT(*) FROM tasks WHERE project_id = proj_id AND status = 'done'),
        members_count = (SELECT COUNT(*) FROM project_permissions WHERE project_id = proj_id),
        last_activity = NOW(),
        updated_at = NOW()
    WHERE id = proj_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour mettre à jour les statistiques des snippets publics
CREATE OR REPLACE FUNCTION update_public_snippet_stats()
RETURNS TRIGGER AS $$
DECLARE
    snippet_id UUID;
BEGIN
    snippet_id := COALESCE(NEW.snippet_id, OLD.snippet_id);
    
    UPDATE public_snippets SET
        likes_count = (SELECT COUNT(*) FROM public_snippet_likes WHERE snippet_id = snippet_id),
        forks_count = (SELECT COUNT(*) FROM public_snippet_forks WHERE original_snippet_id = snippet_id)
    WHERE id = snippet_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour updated_at automatique
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer les triggers
CREATE TRIGGER trigger_update_project_stats_notes
    AFTER INSERT OR UPDATE OR DELETE ON project_notes
    FOR EACH ROW EXECUTE FUNCTION update_project_stats();

CREATE TRIGGER trigger_update_project_stats_snippets
    AFTER INSERT OR UPDATE OR DELETE ON project_snippets
    FOR EACH ROW EXECUTE FUNCTION update_project_stats();

CREATE TRIGGER trigger_update_project_stats_tasks
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_project_stats();

CREATE TRIGGER trigger_update_project_stats_permissions
    AFTER INSERT OR UPDATE OR DELETE ON project_permissions
    FOR EACH ROW EXECUTE FUNCTION update_project_stats();

CREATE TRIGGER trigger_update_public_snippet_likes
    AFTER INSERT OR DELETE ON public_snippet_likes
    FOR EACH ROW EXECUTE FUNCTION update_public_snippet_stats();

CREATE TRIGGER trigger_update_public_snippet_forks
    AFTER INSERT OR DELETE ON public_snippet_forks
    FOR EACH ROW EXECUTE FUNCTION update_public_snippet_stats();

-- Triggers pour updated_at
CREATE TRIGGER trigger_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_permissions_updated_at BEFORE UPDATE ON project_permissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_notes_updated_at BEFORE UPDATE ON project_notes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_snippets_updated_at BEFORE UPDATE ON project_snippets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_public_snippets_updated_at BEFORE UPDATE ON public_snippets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_messages_updated_at BEFORE UPDATE ON messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_comments_updated_at BEFORE UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- FONCTIONS UTILITAIRES
-- =============================================================================

-- Fonction pour vérifier les permissions d'un utilisateur sur un projet
CREATE OR REPLACE FUNCTION user_has_project_permission(
    p_user_id UUID,
    p_project_id UUID,
    p_permission VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    user_role VARCHAR(20);
    has_permission BOOLEAN := FALSE;
BEGIN
    -- Vérifier si l'utilisateur est le propriétaire
    IF EXISTS(SELECT 1 FROM projects WHERE id = p_project_id AND owner_id = p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Récupérer le rôle de l'utilisateur
    SELECT role INTO user_role
    FROM project_permissions
    WHERE project_id = p_project_id AND user_id = p_user_id;
    
    -- Vérifier selon le rôle
    CASE user_role
        WHEN 'admin' THEN
            has_permission := TRUE;
        WHEN 'editor' THEN
            has_permission := p_permission NOT IN ('can_manage_members', 'can_edit_project');
        WHEN 'viewer' THEN
            has_permission := p_permission IN ('can_view');
        ELSE
            has_permission := FALSE;
    END CASE;
    
    RETURN has_permission;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- DONNÉES INITIALES
-- =============================================================================

-- Rôles par défaut et leurs permissions
INSERT INTO project_permissions (project_id, user_id, role, can_edit_project, can_manage_members, can_create_notes, can_edit_notes, can_delete_notes, can_create_snippets, can_edit_snippets, can_delete_snippets, can_create_tasks, can_edit_tasks, can_delete_tasks)
VALUES 
-- Les valeurs seront insérées lors de la création d'un projet
-- owner: toutes les permissions
-- admin: toutes sauf edit_project
-- editor: créer/éditer mais pas supprimer
-- viewer: lecture seule
('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'owner', true, true, true, true, true, true, true, true, true, true, true)
ON CONFLICT DO NOTHING;
