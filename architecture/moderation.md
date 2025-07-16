# Système de Modération ETTU

## Vue d'ensemble

Le système de modération d'ETTU est conçu pour maintenir la qualité du contenu tout en préservant la liberté d'expression et l'innovation.

## Architecture de modération

### Niveaux de modération

1. **Automatique** : Filtres et règles automatiques
2. **Communautaire** : Signalements et votes de la communauté
3. **Humaine** : Modération par l'équipe

### Entités modérées

- **Snippets publics** : Code partagé publiquement
- **Commentaires** : Commentaires sur snippets et projets
- **Utilisateurs** : Comportement et réputation
- **Messages** : Communications entre utilisateurs

## Système de réputation

### Calcul de la réputation

```sql
CREATE TABLE user_reputation (
    user_id UUID REFERENCES users(id),
    reputation_score INT DEFAULT 0,
    positive_actions INT DEFAULT 0,
    negative_actions INT DEFAULT 0,
    
    -- Facteurs positifs
    snippet_likes INT DEFAULT 0,
    snippet_forks INT DEFAULT 0,
    valid_reports INT DEFAULT 0,
    
    -- Facteurs négatifs
    invalid_reports INT DEFAULT 0,
    warnings_received INT DEFAULT 0,
    content_removed INT DEFAULT 0,
    
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Algorithme de réputation

```sql
CREATE OR REPLACE FUNCTION calculate_user_reputation(p_user_id UUID) 
RETURNS INT AS $$
DECLARE
    base_score INT := 0;
    snippet_score INT := 0;
    community_score INT := 0;
    penalty_score INT := 0;
    final_score INT := 0;
BEGIN
    -- Score de base (utilisateur enregistré)
    SELECT CASE 
        WHEN user_type IN ('registered', 'migrated') THEN 10
        ELSE 0
    END INTO base_score
    FROM users WHERE id = p_user_id;
    
    -- Score des snippets
    SELECT 
        (snippet_likes * 2) + 
        (snippet_forks * 5) + 
        (valid_reports * 3)
    INTO snippet_score
    FROM user_reputation WHERE user_id = p_user_id;
    
    -- Score communautaire
    SELECT 
        COUNT(DISTINCT psl.user_id) * 1  -- Likes reçus
    INTO community_score
    FROM public_snippets ps
    JOIN public_snippet_likes psl ON ps.id = psl.snippet_id
    WHERE ps.author_id = p_user_id;
    
    -- Pénalités
    SELECT 
        (invalid_reports * -2) + 
        (warnings_received * -5) + 
        (content_removed * -10)
    INTO penalty_score
    FROM user_reputation WHERE user_id = p_user_id;
    
    final_score := base_score + snippet_score + community_score + penalty_score;
    
    -- Mise à jour du score
    UPDATE user_reputation 
    SET reputation_score = final_score, calculated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN final_score;
END;
$$ LANGUAGE plpgsql;
```

## Modération automatique

### Filtres de contenu

```rust
pub struct ContentFilter {
    pub spam_keywords: Vec<String>,
    pub inappropriate_patterns: Vec<Regex>,
    pub security_vulnerabilities: Vec<SecurityPattern>,
    pub copyright_indicators: Vec<String>,
}

impl ContentFilter {
    pub fn check_snippet(&self, snippet: &Snippet) -> ModerationResult {
        let mut issues = Vec::new();
        
        // Vérifier le spam
        if self.contains_spam(&snippet.code) {
            issues.push(ModerationIssue::Spam);
        }
        
        // Vérifier le contenu inapproprié
        if self.contains_inappropriate_content(&snippet.description) {
            issues.push(ModerationIssue::Inappropriate);
        }
        
        // Vérifier les vulnérabilités de sécurité
        if self.contains_security_issues(&snippet.code) {
            issues.push(ModerationIssue::Security);
        }
        
        // Vérifier les violations de copyright
        if self.contains_copyright_violations(&snippet.code) {
            issues.push(ModerationIssue::Copyright);
        }
        
        ModerationResult::new(issues)
    }
}
```

### Actions automatiques

```sql
-- Fonction pour actions automatiques
CREATE OR REPLACE FUNCTION apply_automatic_moderation(
    p_entity_type VARCHAR(20),
    p_entity_id UUID,
    p_issues JSONB
) RETURNS VOID AS $$
DECLARE
    issue_count INT;
    severity_level INT;
BEGIN
    issue_count := jsonb_array_length(p_issues);
    
    -- Calculer la sévérité
    SELECT SUM(
        CASE 
            WHEN value->>'type' = 'spam' THEN 3
            WHEN value->>'type' = 'inappropriate' THEN 2
            WHEN value->>'type' = 'security' THEN 5
            WHEN value->>'type' = 'copyright' THEN 4
            ELSE 1
        END
    ) INTO severity_level
    FROM jsonb_array_elements(p_issues);
    
    -- Actions selon la sévérité
    IF severity_level >= 5 THEN
        -- Masquer automatiquement
        UPDATE public_snippets 
        SET moderation_status = 'flagged', 
            moderated_at = NOW(),
            moderation_note = 'Automatic moderation: high severity issues'
        WHERE id = p_entity_id;
    ELSIF severity_level >= 3 THEN
        -- Marquer pour révision
        UPDATE public_snippets 
        SET moderation_status = 'pending',
            moderation_note = 'Automatic flagging: moderate issues'
        WHERE id = p_entity_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

## Modération communautaire

### Système de signalements

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES users(id),
    entity_type VARCHAR(20) NOT NULL,
    entity_id UUID NOT NULL,
    reason VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    resolution_note TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Raisons de signalement

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReportReason {
    Spam,
    Inappropriate,
    Copyright,
    Security,
    Misleading,
    Other,
}

pub struct ReportRequest {
    pub entity_type: String,
    pub entity_id: Uuid,
    pub reason: ReportReason,
    pub description: Option<String>,
}
```

### Traitement des signalements

```sql
-- Fonction pour traiter les signalements
CREATE OR REPLACE FUNCTION process_report(
    p_report_id UUID,
    p_moderator_id UUID,
    p_action VARCHAR(20),
    p_resolution_note TEXT
) RETURNS VOID AS $$
DECLARE
    report_record RECORD;
    reporter_reputation INT;
BEGIN
    -- Récupérer le signalement
    SELECT * INTO report_record
    FROM reports WHERE id = p_report_id;
    
    -- Marquer comme traité
    UPDATE reports 
    SET status = 'resolved',
        reviewed_by = p_moderator_id,
        reviewed_at = NOW(),
        resolution_note = p_resolution_note
    WHERE id = p_report_id;
    
    -- Calculer l'impact sur la réputation
    SELECT reputation_score INTO reporter_reputation
    FROM user_reputation 
    WHERE user_id = report_record.reporter_id;
    
    -- Récompenser ou pénaliser le signaleur
    IF p_action = 'valid' THEN
        UPDATE user_reputation 
        SET valid_reports = valid_reports + 1,
            reputation_score = reputation_score + 3
        WHERE user_id = report_record.reporter_id;
    ELSIF p_action = 'invalid' THEN
        UPDATE user_reputation 
        SET invalid_reports = invalid_reports + 1,
            reputation_score = reputation_score - 1
        WHERE user_id = report_record.reporter_id;
    END IF;
    
    -- Logger l'action de modération
    INSERT INTO moderation_actions (
        moderator_id, entity_type, entity_id, action_type, reason, details
    ) VALUES (
        p_moderator_id, report_record.entity_type, report_record.entity_id, 
        p_action, p_resolution_note, 
        jsonb_build_object('report_id', p_report_id, 'reason', report_record.reason)
    );
END;
$$ LANGUAGE plpgsql;
```

## Modération humaine

### Actions disponibles

```sql
CREATE TABLE moderation_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    moderator_id UUID REFERENCES users(id),
    target_user_id UUID REFERENCES users(id),
    entity_type VARCHAR(20),
    entity_id UUID,
    action_type VARCHAR(30) NOT NULL,
    reason TEXT NOT NULL,
    details JSONB,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Types d'actions

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ModerationAction {
    Warn,           // Avertissement
    Restrict,       // Restriction temporaire
    Ban,            // Bannissement
    Delete,         // Suppression de contenu
    Edit,           // Modification forcée
    Feature,        // Mise en avant
    Approve,        // Approbation
    Reject,         // Rejet
}

pub struct ModerationRequest {
    pub target_user_id: Option<Uuid>,
    pub entity_type: Option<String>,
    pub entity_id: Option<Uuid>,
    pub action: ModerationAction,
    pub reason: String,
    pub duration: Option<Duration>,
    pub details: Option<serde_json::Value>,
}
```

### Interface de modération

```rust
pub async fn moderate_content(
    Extension(current_user): Extension<CurrentUser>,
    Json(request): Json<ModerationRequest>,
) -> Result<Json<ModerationResponse>, StatusCode> {
    // Vérifier les permissions de modération
    if !user_has_permission(&current_user, "moderate_content").await? {
        return Err(StatusCode::FORBIDDEN);
    }
    
    // Appliquer l'action
    match request.action {
        ModerationAction::Delete => {
            delete_content(&request.entity_type, &request.entity_id).await?;
        }
        ModerationAction::Ban => {
            ban_user(&request.target_user_id, &request.duration).await?;
        }
        ModerationAction::Approve => {
            approve_content(&request.entity_type, &request.entity_id).await?;
        }
        // ... autres actions
    }
    
    // Logger l'action
    log_moderation_action(&current_user, &request).await?;
    
    Ok(Json(ModerationResponse::success()))
}
```

## Système d'appel

### Processus d'appel

```sql
CREATE TABLE moderation_appeals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    moderation_action_id UUID REFERENCES moderation_actions(id),
    appeal_reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    decision VARCHAR(20), -- 'upheld', 'overturned', 'modified'
    decision_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Traitement des appels

```rust
pub async fn submit_appeal(
    Extension(current_user): Extension<CurrentUser>,
    Json(appeal): Json<AppealRequest>,
) -> Result<Json<AppealResponse>, StatusCode> {
    // Vérifier que l'utilisateur peut faire appel
    if !can_submit_appeal(&current_user, &appeal.moderation_action_id).await? {
        return Err(StatusCode::FORBIDDEN);
    }
    
    // Créer l'appel
    let appeal_id = create_appeal(&current_user, &appeal).await?;
    
    // Notifier les modérateurs
    notify_moderators_of_appeal(&appeal_id).await?;
    
    Ok(Json(AppealResponse::new(appeal_id)))
}
```

## Escalade automatique

### Règles d'escalade

```sql
-- Fonction pour escalade automatique
CREATE OR REPLACE FUNCTION check_escalation_rules()
RETURNS VOID AS $$
DECLARE
    high_report_users CURSOR FOR
        SELECT user_id, COUNT(*) as report_count
        FROM reports
        WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY user_id
        HAVING COUNT(*) >= 5;
    
    suspicious_patterns CURSOR FOR
        SELECT entity_id, entity_type, COUNT(*) as pattern_count
        FROM reports
        WHERE created_at > NOW() - INTERVAL '1 hour'
        GROUP BY entity_id, entity_type
        HAVING COUNT(*) >= 3;
BEGIN
    -- Escalader les utilisateurs avec beaucoup de signalements
    FOR user_record IN high_report_users LOOP
        INSERT INTO moderation_actions (
            moderator_id, target_user_id, action_type, reason, details
        ) VALUES (
            NULL, user_record.user_id, 'auto_restrict', 
            'Automatic escalation: high report volume',
            jsonb_build_object('report_count', user_record.report_count)
        );
    END LOOP;
    
    -- Escalader le contenu suspect
    FOR content_record IN suspicious_patterns LOOP
        UPDATE public_snippets 
        SET moderation_status = 'flagged',
            moderation_note = 'Automatic escalation: multiple reports'
        WHERE id = content_record.entity_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## Métriques de modération

### Tableau de bord

```sql
-- Vue pour métriques de modération
CREATE VIEW moderation_metrics AS
SELECT 
    DATE_TRUNC('day', created_at) as day,
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE status = 'resolved') as resolved_reports,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_reports,
    AVG(EXTRACT(EPOCH FROM (reviewed_at - created_at))/3600) as avg_resolution_time_hours
FROM reports
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY day DESC;
```

### Alertes

```rust
pub async fn check_moderation_alerts() -> Result<Vec<Alert>, Error> {
    let mut alerts = Vec::new();
    
    // Vérifier la charge de travail
    let pending_reports = get_pending_reports_count().await?;
    if pending_reports > 50 {
        alerts.push(Alert::high_workload(pending_reports));
    }
    
    // Vérifier les temps de réponse
    let avg_response_time = get_avg_response_time().await?;
    if avg_response_time > Duration::from_hours(24) {
        alerts.push(Alert::slow_response(avg_response_time));
    }
    
    // Vérifier les patterns suspects
    let suspicious_activity = detect_suspicious_patterns().await?;
    if !suspicious_activity.is_empty() {
        alerts.push(Alert::suspicious_activity(suspicious_activity));
    }
    
    Ok(alerts)
}
```

## Configuration

### Paramètres de modération

```rust
pub struct ModerationConfig {
    pub auto_moderation_enabled: bool,
    pub spam_threshold: f32,
    pub inappropriate_threshold: f32,
    pub min_reputation_for_reports: i32,
    pub max_reports_per_user_per_day: u32,
    pub escalation_report_threshold: u32,
    pub appeal_deadline_days: u32,
}
```

### Personnalisation par communauté

```sql
-- Configuration par catégorie
CREATE TABLE moderation_settings (
    category VARCHAR(50) PRIMARY KEY,
    auto_approval_threshold INT DEFAULT 10,
    require_review BOOLEAN DEFAULT TRUE,
    community_voting_enabled BOOLEAN DEFAULT FALSE,
    settings JSONB DEFAULT '{}'
);
```

## Tests et validation

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_automatic_moderation() {
        let spam_snippet = create_spam_snippet().await;
        let result = moderate_automatically(&spam_snippet).await;
        
        assert_eq!(result.status, ModerationStatus::Flagged);
        assert!(result.issues.contains(&ModerationIssue::Spam));
    }
    
    #[tokio::test]
    async fn test_reputation_calculation() {
        let user = create_test_user().await;
        add_positive_actions(&user, 10).await;
        
        let reputation = calculate_user_reputation(&user.id).await;
        assert!(reputation > 0);
    }
}
```
