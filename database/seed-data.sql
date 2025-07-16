-- =============================================================================
-- DONNÉES INITIALES POUR ETTU BACKEND
-- =============================================================================

-- Supprimer les données existantes (pour les tests)
-- DELETE FROM default_permissions;
-- DELETE FROM role_permissions;

-- =============================================================================
-- PERMISSIONS PAR DÉFAUT POUR UTILISATEURS HYBRIDES
-- =============================================================================

-- Permissions pour les utilisateurs invités
INSERT INTO default_permissions (user_type, permission, is_granted) VALUES
-- Projets
('guest', 'create_projects', TRUE),
('guest', 'edit_own_projects', TRUE),
('guest', 'delete_own_projects', TRUE),
('guest', 'view_own_projects', TRUE),

-- Notes
('guest', 'create_notes', TRUE),
('guest', 'edit_own_notes', TRUE),
('guest', 'delete_own_notes', TRUE),
('guest', 'view_own_notes', TRUE),

-- Snippets
('guest', 'create_snippets', TRUE),
('guest', 'edit_own_snippets', TRUE),
('guest', 'delete_own_snippets', TRUE),
('guest', 'view_own_snippets', TRUE),

-- Tâches
('guest', 'create_tasks', TRUE),
('guest', 'edit_own_tasks', TRUE),
('guest', 'delete_own_tasks', TRUE),
('guest', 'view_own_tasks', TRUE),

-- Général
('guest', 'export_data', TRUE),
('guest', 'view_public_snippets', TRUE)

ON CONFLICT (user_type, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les utilisateurs enregistrés (héritent des permissions invité)
INSERT INTO default_permissions (user_type, permission, is_granted) VALUES
-- Permissions de base (identiques aux invités)
('registered', 'create_projects', TRUE),
('registered', 'edit_own_projects', TRUE),
('registered', 'delete_own_projects', TRUE),
('registered', 'view_own_projects', TRUE),
('registered', 'create_notes', TRUE),
('registered', 'edit_own_notes', TRUE),
('registered', 'delete_own_notes', TRUE),
('registered', 'view_own_notes', TRUE),
('registered', 'create_snippets', TRUE),
('registered', 'edit_own_snippets', TRUE),
('registered', 'delete_own_snippets', TRUE),
('registered', 'view_own_snippets', TRUE),
('registered', 'create_tasks', TRUE),
('registered', 'edit_own_tasks', TRUE),
('registered', 'delete_own_tasks', TRUE),
('registered', 'view_own_tasks', TRUE),
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
('registered', 'report_content', TRUE),
('registered', 'create_collections', TRUE),
('registered', 'join_teams', TRUE),
('registered', 'invite_members', TRUE)

ON CONFLICT (user_type, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les utilisateurs migrés (identiques aux enregistrés)
INSERT INTO default_permissions (user_type, permission, is_granted) 
SELECT 'migrated', permission, is_granted 
FROM default_permissions 
WHERE user_type = 'registered'
ON CONFLICT (user_type, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- =============================================================================
-- RÔLES GLOBAUX ET LEURS PERMISSIONS
-- =============================================================================

-- Permissions pour les administrateurs
INSERT INTO role_permissions (role, permission, is_granted) VALUES
('admin', 'manage_users', TRUE),
('admin', 'manage_system', TRUE),
('admin', 'view_all_content', TRUE),
('admin', 'moderate_content', TRUE),
('admin', 'manage_permissions', TRUE),
('admin', 'access_admin_panel', TRUE),
('admin', 'view_analytics', TRUE),
('admin', 'manage_backups', TRUE),
('admin', 'configure_system', TRUE),
('admin', 'manage_integrations', TRUE)

ON CONFLICT (role, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les modérateurs
INSERT INTO role_permissions (role, permission, is_granted) VALUES
('moderator', 'moderate_content', TRUE),
('moderator', 'review_reports', TRUE),
('moderator', 'manage_snippets', TRUE),
('moderator', 'warn_users', TRUE),
('moderator', 'temporary_ban', TRUE),
('moderator', 'view_user_activity', TRUE),
('moderator', 'feature_content', TRUE),
('moderator', 'access_moderation_panel', TRUE)

ON CONFLICT (role, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les réviseurs
INSERT INTO role_permissions (role, permission, is_granted) VALUES
('reviewer', 'review_snippets', TRUE),
('reviewer', 'approve_content', TRUE),
('reviewer', 'reject_content', TRUE),
('reviewer', 'edit_content', TRUE),
('reviewer', 'view_pending_content', TRUE),
('reviewer', 'access_review_panel', TRUE)

ON CONFLICT (role, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les utilisateurs standard (aucune permission spéciale)
INSERT INTO role_permissions (role, permission, is_granted) VALUES
('user', 'basic_usage', TRUE)

ON CONFLICT (role, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- Permissions pour les utilisateurs restreints
INSERT INTO role_permissions (role, permission, is_granted) VALUES
('restricted', 'view_public_content', TRUE),
('restricted', 'limited_actions', TRUE)

ON CONFLICT (role, permission) DO UPDATE SET is_granted = EXCLUDED.is_granted;

-- =============================================================================
-- CATÉGORIES DE SNIPPETS PUBLICS
-- =============================================================================

-- Insérer les catégories par défaut pour les snippets publics
INSERT INTO public_snippets (id, title, description, code, language, tags, author_id, category, difficulty, source_type, moderation_status, is_featured, created_at, updated_at)
VALUES 
-- Exemples de snippets pour amorcer la communauté
(
    uuid_generate_v4(),
    'Debounce Hook React',
    'Un hook React personnalisé pour débouncer les valeurs',
    'import { useState, useEffect } from "react";

export function useDebounce(value, delay) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}',
    'javascript',
    '["react", "hooks", "debounce", "performance"]',
    (SELECT id FROM users WHERE user_type = 'registered' LIMIT 1), -- Remplacer par un vrai user_id
    'hooks',
    'intermediate',
    'original',
    'approved',
    TRUE,
    NOW(),
    NOW()
),
(
    uuid_generate_v4(),
    'Validation d\'Email Simple',
    'Fonction utilitaire pour valider les adresses email',
    'export function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export function validateEmail(email) {
  if (!email) {
    return { isValid: false, error: "Email requis" };
  }
  
  if (!isValidEmail(email)) {
    return { isValid: false, error: "Format email invalide" };
  }
  
  return { isValid: true, error: null };
}',
    'javascript',
    '["validation", "email", "utility", "regex"]',
    (SELECT id FROM users WHERE user_type = 'registered' LIMIT 1),
    'utilities',
    'beginner',
    'original',
    'approved',
    FALSE,
    NOW(),
    NOW()
),
(
    uuid_generate_v4(),
    'Gestionnaire de État Local',
    'Hook React pour gérer l\'état local avec localStorage',
    'import { useState, useEffect } from "react";

export function useLocalStorage(key, initialValue) {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Error reading localStorage key "${key}":`, error);
      return initialValue;
    }
  });

  const setValue = (value) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(`Error setting localStorage key "${key}":`, error);
    }
  };

  return [storedValue, setValue];
}',
    'javascript',
    '["react", "hooks", "localStorage", "state"]',
    (SELECT id FROM users WHERE user_type = 'registered' LIMIT 1),
    'hooks',
    'intermediate',
    'original',
    'approved',
    TRUE,
    NOW(),
    NOW()
)

-- On conflit, ne rien faire car ce sont des exemples
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CONFIGURATION DE MODÉRATION
-- =============================================================================

-- Paramètres de modération par catégorie
INSERT INTO moderation_settings (category, auto_approval_threshold, require_review, community_voting_enabled, settings) VALUES
('hooks', 10, TRUE, TRUE, '{"trusted_languages": ["javascript", "typescript"], "max_lines": 200}'),
('utilities', 5, TRUE, FALSE, '{"trusted_languages": ["javascript", "typescript", "python"], "max_lines": 100}'),
('components', 15, TRUE, TRUE, '{"trusted_languages": ["javascript", "typescript", "jsx", "tsx"], "max_lines": 500}'),
('templates', 20, TRUE, TRUE, '{"trusted_languages": ["html", "css", "javascript"], "max_lines": 1000}'),
('algorithms', 25, TRUE, TRUE, '{"trusted_languages": ["python", "java", "cpp", "rust"], "max_lines": 300}'),
('config', 5, TRUE, FALSE, '{"trusted_languages": ["json", "yaml", "toml"], "max_lines": 100}')

ON CONFLICT (category) DO UPDATE SET
  auto_approval_threshold = EXCLUDED.auto_approval_threshold,
  require_review = EXCLUDED.require_review,
  community_voting_enabled = EXCLUDED.community_voting_enabled,
  settings = EXCLUDED.settings;

-- =============================================================================
-- DONNÉES DE DÉMONSTRATION (OPTIONNEL)
-- =============================================================================

-- Créer un utilisateur de démonstration (mot de passe: "demo123!")
INSERT INTO users (
    id, email, username, display_name, password_hash, user_type, 
    is_active, is_verified, theme, language, timezone, 
    created_at, updated_at
) VALUES (
    uuid_generate_v4(),
    'demo@ettu.dev',
    'demo_user',
    'Utilisateur Demo',
    '$2b$12$LQv3c1yqBwlVHpPjrFHn.e3qZo5EqZfj4bKF8Bx6VjfIXQ9eHdPvK', -- demo123!
    'registered',
    TRUE,
    TRUE,
    'dark',
    'fr',
    'Europe/Paris',
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;

-- Créer un projet de démonstration
INSERT INTO projects (
    id, name, description, color, status, owner_id, visibility, 
    settings, technologies, created_at, updated_at
) VALUES (
    uuid_generate_v4(),
    'Projet Demo ETTU',
    'Un projet de démonstration pour montrer les fonctionnalités d\'ETTU',
    '#3b82f6',
    'active',
    (SELECT id FROM users WHERE email = 'demo@ettu.dev'),
    'public',
    '{"allowPublicSharing": true, "enableDiscussions": true}',
    '["React", "TypeScript", "Node.js", "PostgreSQL"]',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- MISE À JOUR DES STATISTIQUES
-- =============================================================================

-- Mettre à jour les compteurs de réputation (si la table existe)
INSERT INTO user_reputation (user_id, reputation_score, positive_actions, negative_actions, snippet_likes, snippet_forks, calculated_at)
SELECT 
    u.id,
    10, -- Score de base pour les utilisateurs enregistrés
    0,
    0,
    0,
    0,
    NOW()
FROM users u
WHERE u.user_type IN ('registered', 'migrated')
ON CONFLICT (user_id) DO UPDATE SET
    reputation_score = EXCLUDED.reputation_score,
    calculated_at = EXCLUDED.calculated_at;

-- =============================================================================
-- VÉRIFICATION DES DONNÉES
-- =============================================================================

-- Vérifier que les données ont été insérées correctement
DO $$
BEGIN
    -- Vérifier les permissions par défaut
    IF NOT EXISTS (SELECT 1 FROM default_permissions WHERE user_type = 'guest') THEN
        RAISE EXCEPTION 'Erreur: Permissions invité non trouvées';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM default_permissions WHERE user_type = 'registered') THEN
        RAISE EXCEPTION 'Erreur: Permissions utilisateur enregistré non trouvées';
    END IF;
    
    -- Vérifier les rôles
    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'admin') THEN
        RAISE EXCEPTION 'Erreur: Permissions administrateur non trouvées';
    END IF;
    
    -- Vérifier les paramètres de modération
    IF NOT EXISTS (SELECT 1 FROM moderation_settings) THEN
        RAISE EXCEPTION 'Erreur: Paramètres de modération non trouvés';
    END IF;
    
    RAISE NOTICE 'Données initiales insérées avec succès';
END $$;

-- =============================================================================
-- FONCTIONS D'AIDE POUR LES TESTS
-- =============================================================================

-- Fonction pour créer un utilisateur de test
CREATE OR REPLACE FUNCTION create_test_user(
    p_email TEXT,
    p_username TEXT DEFAULT NULL,
    p_display_name TEXT DEFAULT NULL,
    p_user_type TEXT DEFAULT 'registered'
) RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    INSERT INTO users (
        email, username, display_name, password_hash, user_type,
        is_active, is_verified, theme, language, timezone
    ) VALUES (
        p_email,
        COALESCE(p_username, split_part(p_email, '@', 1)),
        COALESCE(p_display_name, split_part(p_email, '@', 1)),
        '$2b$12$LQv3c1yqBwlVHpPjrFHn.e3qZo5EqZfj4bKF8Bx6VjfIXQ9eHdPvK', -- demo123!
        p_user_type::VARCHAR,
        TRUE,
        TRUE,
        'dark',
        'fr',
        'Europe/Paris'
    ) RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créer un projet de test
CREATE OR REPLACE FUNCTION create_test_project(
    p_name TEXT,
    p_owner_id UUID,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    new_project_id UUID;
BEGIN
    INSERT INTO projects (
        name, description, color, status, owner_id, visibility
    ) VALUES (
        p_name,
        COALESCE(p_description, 'Projet de test: ' || p_name),
        '#' || lpad(to_hex(floor(random() * 16777215)::int), 6, '0'),
        'active',
        p_owner_id,
        'private'
    ) RETURNING id INTO new_project_id;
    
    RETURN new_project_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nettoyer les données de test
CREATE OR REPLACE FUNCTION cleanup_test_data() RETURNS VOID AS $$
BEGIN
    -- Supprimer les utilisateurs de test
    DELETE FROM users WHERE email LIKE '%test%' OR email LIKE '%example%';
    
    -- Supprimer les projets orphelins
    DELETE FROM projects WHERE owner_id NOT IN (SELECT id FROM users);
    
    -- Supprimer les snippets orphelins
    DELETE FROM public_snippets WHERE author_id NOT IN (SELECT id FROM users);
    
    -- Nettoyer les sessions expirées
    DELETE FROM user_sessions WHERE expires_at < NOW();
    
    RAISE NOTICE 'Données de test nettoyées';
END;
$$ LANGUAGE plpgsql;

-- Message de confirmation
SELECT 'Données initiales ETTU chargées avec succès!' as message;
