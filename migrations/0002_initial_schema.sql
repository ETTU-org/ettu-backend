-- Migration initiale ETTU - Schéma complet
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

-- =============================================================================
-- TABLES PROJETS & PERMISSIONS
-- =============================================================================

-- Table des projets
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7) NOT NULL DEFAULT '#3b82f6', -- Couleur hex
    icon VARCHAR(50) DEFAULT 'folder',
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'archived')),
    
    -- Propriétaire du projet
    owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Visibilité et partage
    visibility VARCHAR(10) NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'team', 'public')),
    is_template BOOLEAN DEFAULT FALSE,
    template_category VARCHAR(50),
    
    -- Métadonnées
    technologies JSONB DEFAULT '[]',
    repository_url VARCHAR(255),
    live_url VARCHAR(255),
    
    -- Configuration
    settings JSONB DEFAULT '{
        "allowPublicSharing": false,
        "defaultNoteType": "brief",
        "defaultSnippetLanguage": "javascript",
        "enableComments": true,
        "enableTasks": true,
        "enableDiscussions": true
    }',
    
    -- Version pour optimistic locking
    version INT DEFAULT 1,
    
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
-- INDEXES POUR PERFORMANCES
-- =============================================================================

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_anonymous_id ON users(anonymous_id) WHERE anonymous_id IS NOT NULL;
CREATE INDEX idx_users_user_type ON users(user_type);

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
CREATE INDEX idx_public_snippets_moderation ON public_snippets(moderation_status);
CREATE INDEX idx_public_snippets_trending ON public_snippets(trending_score DESC);

-- Tasks
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_author_id ON tasks(author_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

-- Notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- =============================================================================
-- TRIGGERS POUR UPDATED_AT
-- =============================================================================

-- Fonction pour updated_at automatique
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour updated_at
CREATE TRIGGER trigger_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_permissions_updated_at BEFORE UPDATE ON project_permissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_notes_updated_at BEFORE UPDATE ON project_notes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_project_snippets_updated_at BEFORE UPDATE ON project_snippets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_public_snippets_updated_at BEFORE UPDATE ON public_snippets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
