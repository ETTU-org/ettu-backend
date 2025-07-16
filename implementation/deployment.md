# Guide de Déploiement ETTU Backend

## Vue d'ensemble

Ce guide couvre le déploiement complet du backend ETTU en production, incluant la configuration, la sécurité, le monitoring, et la maintenance.

## Architecture de déploiement

### Configuration recommandée

```
Production Environment:
┌─────────────────────────────────────────────────────────────┐
│                      Load Balancer                          │
│                      (Nginx/HAProxy)                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  Backend Instances                          │
│            (2+ instances Rust/Axum)                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────┬───────┴───────┬─────────────────────────────┐
│   PostgreSQL    │     Redis     │       File Storage          │
│   (Primary +    │    Cluster    │      (S3/MinIO)             │
│   Replicas)     │               │                             │
└─────────────────┴───────────────┴─────────────────────────────┘
```

## Préparation du déploiement

### 1. Build de production

```bash
# Optimiser pour la production
cargo build --release

# Ou utiliser Docker multi-stage
docker build -t ettu-backend:latest .
```

### 2. Dockerfile optimisé

```dockerfile
# Build stage
FROM rust:1.75-slim as builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY Cargo.toml Cargo.lock ./

# Créer un projet temporaire pour cacher les dépendances
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copier le code source
COPY src ./src
COPY database ./database
COPY config ./config

# Build final
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -u 1000 ettu

WORKDIR /app

# Copier le binaire
COPY --from=builder /app/target/release/ettu-backend ./
COPY --from=builder /app/config ./config

# Changer le propriétaire
RUN chown -R ettu:ettu /app

USER ettu

EXPOSE 3000

CMD ["./ettu-backend"]
```

### 3. Docker Compose pour production

```yaml
version: "3.8"

services:
  backend:
    image: ettu-backend:latest
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 512M
    environment:
      - RUST_LOG=info
      - DATABASE_URL=postgresql://ettu_user:${DB_PASSWORD}@postgres:5432/ettu_prod
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    networks:
      - ettu-network

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=ettu_prod
      - POSTGRES_USER=ettu_user
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - ettu-network

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - ettu-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - backend
    networks:
      - ettu-network

volumes:
  postgres_data:
  redis_data:

networks:
  ettu-network:
    driver: bridge
```

## Configuration Nginx

### nginx.conf

```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    upstream backend {
        server backend:3000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name ettu.dev www.ettu.dev;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name ettu.dev www.ettu.dev;

        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        # API routes
        location /api/ {
            limit_req zone=api burst=20 nodelay;

            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Auth routes with stricter rate limiting
        location /api/auth/ {
            limit_req zone=auth burst=5 nodelay;

            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket endpoint
        location /ws {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check
        location /health {
            proxy_pass http://backend;
            access_log off;
        }

        # Frontend (si servi par Nginx)
        location / {
            root /var/www/html;
            try_files $uri $uri/ /index.html;
        }
    }
}
```

## Configuration de la base de données

### PostgreSQL en production

```sql
-- Configuration PostgreSQL (postgresql.conf)
shared_preload_libraries = 'pg_stat_statements'
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB

-- Réplication (master)
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
hot_standby = on
```

### Script d'initialisation

```bash
#!/bin/bash
# init-db.sh

set -e

# Créer l'utilisateur et la base de données
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER ettu_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
    CREATE DATABASE ettu_prod OWNER ettu_user;
    GRANT ALL PRIVILEGES ON DATABASE ettu_prod TO ettu_user;

    \c ettu_prod
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "citext";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOSQL

# Exécuter le schéma
psql -v ON_ERROR_STOP=1 --username "ettu_user" --dbname "ettu_prod" < /docker-entrypoint-initdb.d/schema.sql
```

## Monitoring et observabilité

### Prometheus metrics

```rust
use prometheus::{Counter, Histogram, Gauge, Registry};
use std::sync::Arc;

#[derive(Clone)]
pub struct Metrics {
    pub requests_total: Counter,
    pub request_duration: Histogram,
    pub active_connections: Gauge,
    pub database_connections: Gauge,
    pub redis_connections: Gauge,
}

impl Metrics {
    pub fn new() -> Self {
        Self {
            requests_total: Counter::new("http_requests_total", "Total HTTP requests").unwrap(),
            request_duration: Histogram::new("http_request_duration_seconds", "HTTP request duration").unwrap(),
            active_connections: Gauge::new("active_connections", "Active connections").unwrap(),
            database_connections: Gauge::new("database_connections", "Database connections").unwrap(),
            redis_connections: Gauge::new("redis_connections", "Redis connections").unwrap(),
        }
    }

    pub fn register(&self, registry: &Registry) {
        registry.register(Box::new(self.requests_total.clone())).unwrap();
        registry.register(Box::new(self.request_duration.clone())).unwrap();
        registry.register(Box::new(self.active_connections.clone())).unwrap();
        registry.register(Box::new(self.database_connections.clone())).unwrap();
        registry.register(Box::new(self.redis_connections.clone())).unwrap();
    }
}

// Middleware pour les métriques
pub async fn metrics_middleware(
    Extension(metrics): Extension<Arc<Metrics>>,
    req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let start = std::time::Instant::now();

    metrics.requests_total.inc();
    metrics.active_connections.inc();

    let response = next.run(req).await;

    let duration = start.elapsed();
    metrics.request_duration.observe(duration.as_secs_f64());
    metrics.active_connections.dec();

    Ok(response)
}
```

### Configuration Prometheus

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "ettu-backend"
    static_configs:
      - targets: ["backend:3000"]
    metrics_path: /metrics
    scrape_interval: 5s

  - job_name: "postgres"
    static_configs:
      - targets: ["postgres:5432"]

  - job_name: "redis"
    static_configs:
      - targets: ["redis:6379"]

  - job_name: "nginx"
    static_configs:
      - targets: ["nginx:80"]
```

### Alertes Grafana

```yaml
# alerting.yml
groups:
  - name: ettu-backend
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} requests per second"

      - alert: DatabaseConnectionsHigh
        expr: database_connections > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Database connections high"
          description: "Database connections: {{ $value }}"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "Service {{ $labels.job }} is down"
```

## Sauvegardes

### Script de sauvegarde automatique

```bash
#!/bin/bash
# backup.sh

set -e

# Configuration
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Créer le répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

# Sauvegarde PostgreSQL
echo "Starting PostgreSQL backup..."
pg_dump -h postgres -U ettu_user -d ettu_prod -F c -f "$BACKUP_DIR/postgres_$DATE.dump"

# Sauvegarde Redis
echo "Starting Redis backup..."
redis-cli -h redis --rdb "$BACKUP_DIR/redis_$DATE.rdb"

# Chiffrement des sauvegardes
echo "Encrypting backups..."
gpg --cipher-algo AES256 --compress-algo 1 --symmetric --output "$BACKUP_DIR/postgres_$DATE.dump.gpg" "$BACKUP_DIR/postgres_$DATE.dump"
gpg --cipher-algo AES256 --compress-algo 1 --symmetric --output "$BACKUP_DIR/redis_$DATE.rdb.gpg" "$BACKUP_DIR/redis_$DATE.rdb"

# Supprimer les fichiers non chiffrés
rm "$BACKUP_DIR/postgres_$DATE.dump" "$BACKUP_DIR/redis_$DATE.rdb"

# Upload vers S3 (optionnel)
if [ -n "$S3_BUCKET" ]; then
    echo "Uploading to S3..."
    aws s3 cp "$BACKUP_DIR/postgres_$DATE.dump.gpg" "s3://$S3_BUCKET/backups/"
    aws s3 cp "$BACKUP_DIR/redis_$DATE.rdb.gpg" "s3://$S3_BUCKET/backups/"
fi

# Nettoyage des anciennes sauvegardes
echo "Cleaning old backups..."
find "$BACKUP_DIR" -name "*.gpg" -mtime +$RETENTION_DAYS -delete

echo "Backup completed successfully"
```

### Cron job

```bash
# Ajouter au crontab
0 2 * * * /opt/ettu/backup.sh >> /var/log/backup.log 2>&1
```

## Déploiement continu

### GitHub Actions

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ secrets.REGISTRY_URL }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v3
        with:
          push: true
          tags: ${{ secrets.REGISTRY_URL }}/ettu-backend:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Deploy to server
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/ettu
            docker-compose pull
            docker-compose up -d --remove-orphans
            docker system prune -f
```

## Sécurité en production

### Durcissement du serveur

```bash
#!/bin/bash
# security-hardening.sh

# Mise à jour du système
apt update && apt upgrade -y

# Installer fail2ban
apt install -y fail2ban

# Configuration fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

# Redémarrer fail2ban
systemctl restart fail2ban

# Configuration du firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Désactiver les services inutiles
systemctl disable bluetooth
systemctl disable cups
systemctl disable avahi-daemon

# Configuration SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

systemctl restart sshd
```

### Certificats SSL

```bash
#!/bin/bash
# ssl-setup.sh

# Installer certbot
apt install -y certbot python3-certbot-nginx

# Obtenir le certificat
certbot --nginx -d ettu.dev -d www.ettu.dev

# Renouvellement automatique
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

## Maintenance et troubleshooting

### Scripts de maintenance

```bash
#!/bin/bash
# maintenance.sh

echo "=== ETTU Backend Maintenance ==="

# Vérifier les services
echo "Checking services..."
docker-compose ps

# Vérifier l'espace disque
echo "Disk usage:"
df -h

# Vérifier les logs
echo "Recent errors:"
docker-compose logs --tail=50 backend | grep -i error

# Nettoyage Docker
echo "Cleaning up Docker..."
docker system prune -f
docker volume prune -f

# Vérifier les connexions DB
echo "Database connections:"
docker exec postgres psql -U ettu_user -d ettu_prod -c "SELECT count(*) FROM pg_stat_activity;"

# Vérifier Redis
echo "Redis info:"
docker exec redis redis-cli info memory

echo "Maintenance completed"
```

### Logs centralisés

```yaml
# docker-compose.logging.yml
version: "3.8"

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.5.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.5.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  elasticsearch_data:
```

## Checklist de déploiement

### Pré-déploiement

- [ ] Tests unitaires et d'intégration passés
- [ ] Tests de charge effectués
- [ ] Sauvegarde de la production actuelle
- [ ] Variables d'environnement configurées
- [ ] Certificats SSL valides
- [ ] Monitoring configuré

### Déploiement

- [ ] Build de production testé
- [ ] Déploiement en mode maintenance
- [ ] Migration de base de données
- [ ] Validation des services
- [ ] Tests de fumée
- [ ] Retour du mode maintenance

### Post-déploiement

- [ ] Vérification des métriques
- [ ] Tests fonctionnels
- [ ] Performance monitoring
- [ ] Logs d'erreurs vérifiés
- [ ] Notification de l'équipe
- [ ] Documentation mise à jour

Ce guide fournit une base complète pour déployer le backend ETTU en production de manière sécurisée et maintenable.
