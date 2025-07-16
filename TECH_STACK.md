# Stack Technique ETTU Backend

## Vue d'ensemble

L'architecture backend d'ETTU est conçue pour être **performante**, **scalable** et **sécurisée**, avec un focus sur l'expérience utilisateur sans friction.

## Technologies principales

### Backend Framework
- **Rust + Axum** 
  - Performance exceptionnelle
  - Sécurité au niveau du type
  - Écosystème mature pour le web
  - Gestion excellente de la concurrence

### Base de données
- **PostgreSQL 15+**
  - ACID compliance
  - Jsonb pour données flexibles
  - Triggers et fonctions PL/pgSQL
  - Extensions (UUID, citext)

### Cache et Sessions
- **Redis**
  - Cache des sessions
  - Données temporaires
  - Pub/Sub pour WebSocket

### Authentification
- **JWT (JSON Web Tokens)**
  - Stateless authentication
  - Support refresh tokens
  - Intégration avec système hybride

### Temps réel
- **WebSocket (tokio-tungstenite)**
  - Collaboration en temps réel
  - Notifications push
  - Synchronisation multi-utilisateurs

## Justifications techniques

### Pourquoi Rust ?
- **Performance**: Comparable au C++ sans garbage collection
- **Sécurité**: Prévention des bugs mémoire au compile-time
- **Concurrence**: Modèle async/await excellent
- **Écosystème**: Crates matures (Axum, Tokio, SQLx, etc.)

### Pourquoi PostgreSQL ?
- **Fiabilité**: Base de données enterprise-grade
- **Flexibilité**: Support JSON/JSONB natif
- **Extensibilité**: Triggers, fonctions, extensions
- **Performance**: Excellent pour les charges mixtes read/write

### Pourquoi Redis ?
- **Rapidité**: Cache en mémoire ultra-rapide
- **Persistance**: Options de persistance configurables
- **Pub/Sub**: Idéal pour les notifications temps réel
- **Structures**: Types de données avancés (sets, hashes, etc.)

## Architecture des dépendances

```toml
[dependencies]
# Framework web
axum = "0.7"
tower = "0.4"
tower-http = "0.5"

# Base de données
sqlx = { version = "0.7", features = ["postgres", "json", "uuid", "chrono"] }
redis = { version = "0.24", features = ["tokio-comp"] }

# Authentification
jsonwebtoken = "9.2"
bcrypt = "0.15"

# Sérialisation
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# Async runtime
tokio = { version = "1.0", features = ["full"] }

# WebSocket
tokio-tungstenite = "0.21"

# Validation
validator = { version = "0.18", features = ["derive"] }

# Configuration
config = "0.14"
dotenv = "0.15"

# Logging
tracing = "0.1"
tracing-subscriber = "0.3"

# Utilitaires
uuid = { version = "1.7", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
```

## Sécurité

### Authentification
- JWT avec rotation des tokens
- Bcrypt pour les mots de passe
- Rate limiting sur les endpoints sensibles
- Audit trail complet

### Base de données
- Paramètres préparés (protection SQL injection)
- Triggers d'audit automatiques
- Chiffrement des données sensibles
- Row Level Security (RLS)

### Transport
- HTTPS obligatoire en production
- CORS configuré strictement
- Headers de sécurité (HSTS, CSP, etc.)

## Performance

### Optimisations
- Connection pooling (SQLx)
- Cache Redis multi-niveaux
- Indexes PostgreSQL optimisés
- Pagination efficace

### Monitoring
- Métriques Prometheus
- Logs structurés (JSON)
- Health checks
- Alertes automatiques

## Scalabilité

### Horizontal scaling
- Stateless backend (JWT)
- Load balancing ready
- Session Redis partagé
- Database read replicas

### Vertical scaling
- Async I/O non-bloquant
- Connection pooling
- Lazy loading
- Batch operations

## Environnements

### Développement
```bash
# Base de données locale
DATABASE_URL=postgresql://user:pass@localhost/ettu_dev

# Redis local
REDIS_URL=redis://localhost:6379

# JWT secret (dev only)
JWT_SECRET=dev_secret_key
```

### Production
```bash
# Base de données managée
DATABASE_URL=postgresql://user:pass@db.example.com/ettu_prod

# Redis cluster
REDIS_URL=redis://cluster.example.com:6379

# JWT secret sécurisé
JWT_SECRET=super_secure_production_key
```

## Monitoring et observabilité

### Métriques
- Latence des requêtes
- Utilisation CPU/mémoire
- Connexions base de données
- Taux d'erreur

### Logs
- Audit trail complet
- Erreurs avec stack traces
- Performances par endpoint
- Événements de sécurité

### Alertes
- Erreurs critiques
- Performance dégradée
- Sécurité compromise
- Capacité dépassée
