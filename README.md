# ETTU Backend

Backend API pour ETTU - Plateforme de gestion de projets, snippets et collaboration pour développeurs.

## 🏗️ Architecture

- **Framework**: Rust + Axum
- **Base de données**: PostgreSQL 15+
- **Cache**: Redis
- **Authentification**: JWT avec système hybride invité/compte
- **Temps réel**: WebSocket pour collaboration

## 🚀 Démarrage rapide

### Prérequis

- Rust 1.75+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optionnel)

### Installation locale

```bash
# Cloner le repository
git clone https://github.com/ETTU-org/ettu-backend.git
cd ettu-backend

# Installer les dépendances
cargo build

# Configurer l'environnement
cp .env.example .env
# Éditer .env avec vos paramètres

# Démarrer les services (Docker)
docker-compose up -d postgres redis

# Exécuter les migrations
cargo run --bin migrate

# Démarrer le serveur
cargo run
```

### Avec Docker

```bash
# Démarrer tous les services
docker-compose up -d

# Voir les logs
docker-compose logs -f backend
```

Ce dossier contient toute l'architecture backend du projet ETTU, organisée de manière modulaire pour faciliter la maintenance et l'implémentation.

## Structure du dossier

```
ettu-backend/
├── README.md                    # Ce fichier
├── TECH_STACK.md               # Stack technique et justifications
├── COMMON_CONFIG.md            # Configuration commune factorises
├── database/                   # Schémas et migrations de base de données
│   ├── schema.sql              # Schéma complet PostgreSQL
│   └── seed-data.sql           # Données initiales et exemples
├── architecture/               # Documents d'architecture
│   ├── hybrid-system.md        # Système hybride invité/compte
│   ├── audit-system.md         # Système d'audit et logging
│   ├── moderation.md           # Système de modération
│   └── permissions.md          # Système de permissions
├── api/                        # Spécifications API
│   ├── hybrid-auth.md          # APIs d'authentification hybride
│   ├── projects.md             # APIs des projets
│   └── snippets.md             # APIs des snippets publics
└── implementation/             # Guides d'implémentation
    ├── rust-setup.md           # Configuration Rust/Axum complète
    ├── deployment.md           # Guide de déploiement production
    └── security.md             # Considérations de sécurité
```

## Démarrage rapide

1. **Database Setup**: Exécutez `database/schema.sql` pour créer la base de données
2. **Backend Setup**: Suivez `implementation/rust-setup.md` pour configurer Rust/Axum
3. **APIs**: Consultez les fichiers dans `api/` pour les spécifications des endpoints

## Caractéristiques principales

- **Système hybride**: Fonctionne sans compte utilisateur avec migration transparente
- **Audit complet**: Tracking de toutes les actions avec capacité de rollback
- **Modération**: Système de réputation et modération communautaire
- **Temps réel**: WebSocket pour collaboration en temps réel
- **Sécurité**: Authentification JWT, audit de sécurité, permissions granulaires

## Technologies

- **Backend**: Rust + Axum + PostgreSQL + Redis
- **Authentification**: JWT avec support guest/registered
- **Temps réel**: WebSocket
- **Cache**: Redis pour sessions et cache
- **Déploiement**: Docker + Docker Compose

## Liens utiles

- [Schema Database](./database/schema.sql)
- [Système Hybride](./architecture/hybrid-system.md)
- [APIs Principales](./api/hybrid-auth.md)
