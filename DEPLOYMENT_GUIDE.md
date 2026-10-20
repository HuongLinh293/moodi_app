# Moodi Backend - Deployment Guide

## Overview

This guide covers deploying the Moodi NestJS backend to production environments. The backend can be deployed to various platforms: Docker, Heroku, AWS, Google Cloud, DigitalOcean, or on-premises servers.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Docker Deployment](#docker-deployment)
4. [Cloud Deployment](#cloud-deployment)
5. [Database Migrations](#database-migrations)
6. [Environment Configuration](#environment-configuration)
7. [Monitoring & Logging](#monitoring--logging)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required
- **Node.js** >= 16.x
- **Docker & Docker Compose** (for containerized deployment)
- **PostgreSQL** >= 12.x
- **Redis** >= 6.x (for real-time features)
- **Git**

### Optional
- **PM2** (for process management)
- **Nginx** (for reverse proxy)
- **SSL Certificate** (for HTTPS)
- **CI/CD Pipeline** (GitHub Actions, GitLab CI, etc.)

---

## Local Development Setup

### 1. Clone and Install

```bash
# Clone repository
git clone <repository-url>
cd moodi_mobile_app/backend

# Install dependencies
npm install --legacy-peer-deps

# Create .env file
cp .env.example .env
```

### 2. Configure Environment Variables

Edit `.env`:
```env
# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=moodi_dev
DATABASE_USER=moodi_user
DATABASE_PASSWORD=your_secure_password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# JWT
JWT_SECRET=your_jwt_secret_key_min_32_chars
JWT_EXPIRY=24h

# API
API_PORT=3000
NODE_ENV=development
```

### 3. Start Services with Docker Compose

```bash
# Start PostgreSQL and Redis
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 4. Run Migrations and Seeds

```bash
# Create and run migrations
npm run migration:run

# Seed test data
npm run seed

# Check database
npm run typeorm migration:show
```

### 5. Start Development Server

```bash
# Development with auto-reload
npm run start:dev

# Production build
npm run build
npm run start:prod
```

Server runs at `http://localhost:3000`  
API docs at `http://localhost:3000/docs`

---

## Docker Deployment

### 1. Build Docker Image

```bash
# Build image
docker build -t moodi-backend:latest .

# Tag for registry
docker tag moodi-backend:latest your-registry/moodi-backend:latest
```

### 2. Docker Compose for Production

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: moodi-postgres
    environment:
      POSTGRES_DB: moodi_prod
      POSTGRES_USER: moodi_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U moodi_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: moodi-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # NestJS Backend
  backend:
    image: moodi-backend:latest
    container_name: moodi-backend
    environment:
      NODE_ENV: production
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: moodi_prod
      DATABASE_USER: moodi_user
      DATABASE_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      API_PORT: 3000
      API_URL: https://api.moodi.app
      CORS_ORIGIN: https://moodi.app
    ports:
      - "3000:3000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Adminer (Optional - Database UI)
  adminer:
    image: adminer:latest
    container_name: moodi-adminer
    ports:
      - "8080:8080"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### 3. Deploy with Docker Compose

```bash
# Start all services
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Stop services
docker-compose -f docker-compose.prod.yml down
```

---

## Cloud Deployment

### AWS EC2

```bash
# 1. SSH into EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-instance.com

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 3. Clone repository
git clone <repository-url>
cd moodi_mobile_app/backend

# 4. Create .env with production values
nano .env

# 5. Build and run with Docker Compose
docker-compose -f docker-compose.prod.yml up -d

# 6. Setup Nginx reverse proxy
sudo apt install nginx
# Configure nginx to proxy to localhost:3000

# 7. Setup SSL with Certbot
sudo apt install certbot python3-certbot-nginx
sudo certbot certonly --nginx -d api.moodi.app
```

### Google Cloud Run

```bash
# 1. Build image
docker build -t gcr.io/your-project/moodi-backend .

# 2. Push to Google Container Registry
docker push gcr.io/your-project/moodi-backend

# 3. Deploy to Cloud Run
gcloud run deploy moodi-backend \
  --image gcr.io/your-project/moodi-backend \
  --platform managed \
  --region us-central1 \
  --set-env-vars DATABASE_HOST=your-db-host,JWT_SECRET=your-secret \
  --allow-unauthenticated
```

### Heroku

```bash
# 1. Install Heroku CLI
curl https://cli-assets.heroku.com/install.sh | sh

# 2. Login to Heroku
heroku login

# 3. Create app
heroku create moodi-backend

# 4. Add PostgreSQL addon
heroku addons:create heroku-postgresql:standard-0 -a moodi-backend

# 5. Add Redis addon
heroku addons:create heroku-redis:premium-0 -a moodi-backend

# 6. Set environment variables
heroku config:set JWT_SECRET=your_secret -a moodi-backend
heroku config:set NODE_ENV=production -a moodi-backend

# 7. Deploy
git push heroku main

# 8. View logs
heroku logs --tail -a moodi-backend

# 9. Run migrations
heroku run npm run migration:run -a moodi-backend
```

### DigitalOcean App Platform

```bash
# 1. Create app.yaml
cat > app.yaml << EOF
name: moodi-backend
services:
- name: backend
  github:
    repo: your-repo
    branch: main
  build_command: npm install --legacy-peer-deps && npm run build
  run_command: npm run start:prod
  http_port: 3000
  envs:
  - key: NODE_ENV
    value: production
  - key: JWT_SECRET
    scope: RUN_AND_BUILD_TIME
    value: ${JWT_SECRET}
EOF

# 2. Deploy with doctl
doctl apps create --spec app.yaml
```

---

## Database Migrations

### Running Migrations

```bash
# Show pending migrations
npm run typeorm migration:show

# Run all pending migrations
npm run migration:run

# Revert last migration
npm run migration:revert

# Generate migration from entity changes
npm run migration:generate -- -n FeatureName
```

### Creating New Migration

```bash
# Generate new migration
npm run migration:create -- -n AddNewTable

# Edit migration file in src/database/migrations/
# Add up() and down() methods

# Run migration
npm run migration:run
```

### Backup Before Migration

```bash
# PostgreSQL backup
pg_dump -U moodi_user -h localhost moodi_prod > backup_$(date +%Y%m%d).sql

# Restore from backup
psql -U moodi_user -h localhost moodi_prod < backup_20261020.sql
```

---

## Environment Configuration

### Production .env Template

```env
# ============ Core ============
NODE_ENV=production
API_PORT=3000
API_URL=https://api.moodi.app

# ============ Database ============
DATABASE_TYPE=postgres
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=moodi_prod
DATABASE_USER=moodi_user
DATABASE_PASSWORD=your_secure_password_min_16_chars
DATABASE_SYNCHRONIZE=false
DATABASE_LOGGING=false

# ============ Redis ============
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password_min_16_chars
REDIS_DB=0

# ============ JWT ============
JWT_SECRET=your_jwt_secret_key_min_32_chars_absolutely_secure
JWT_EXPIRY=24h
REFRESH_TOKEN_EXPIRY=7d

# ============ CORS ============
CORS_ORIGIN=https://moodi.app,https://app.moodi.app
CORS_CREDENTIALS=true

# ============ File Storage ============
STORAGE_MAX_FILE_SIZE=10485760
STORAGE_ALLOWED_TYPES=image/jpeg,image/png,image/webp,video/mp4
STORAGE_PATH=/storage

# ============ Email (Optional) ============
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USER=apikey
MAIL_PASSWORD=your_sendgrid_api_key
MAIL_FROM=noreply@moodi.app

# ============ Logging ============
LOG_LEVEL=warn
LOG_FORMAT=json

# ============ Rate Limiting ============
RATE_LIMIT_WINDOW=900000
RATE_LIMIT_MAX_REQUESTS=100

# ============ Security ============
ENABLE_HELMET=true
ENABLE_COMPRESSION=true
ENABLE_VALIDATION=true
```

### Sensitive Variables

Store these securely:
- `JWT_SECRET` - Use AWS Secrets Manager, Google Secret Manager, or Vault
- `DATABASE_PASSWORD` - Use RDS Master Password or similar
- `REDIS_PASSWORD` - Use Redis AUTH
- `MAIL_PASSWORD` - Use SendGrid/Mailgun API keys

---

## Monitoring & Logging

### PM2 Process Management

```bash
# Install PM2
npm install -g pm2

# Start with PM2
pm2 start dist/main.js --name "moodi-backend"

# Monitor
pm2 monit

# Save configuration
pm2 save
pm2 startup
```

### Health Check Endpoint

The app provides a health check at `GET /health`:

```json
{
  "status": "ok",
  "timestamp": "2024-10-20T10:30:00Z",
  "database": "connected",
  "redis": "connected",
  "uptime": 3600
}
```

### Logging

Configure logging in `.env`:

```env
LOG_LEVEL=info      # error, warn, info, debug
LOG_FORMAT=json     # json or text
```

### Monitoring Tools

**Prometheus Metrics** (Optional):
```bash
npm install @nestjs/terminus @nestjs/metrics
```

**ELK Stack** (Elasticsearch, Logstash, Kibana):
```yaml
# Configure in docker-compose for production
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.0.0
  environment:
    - discovery.type=single-node

kibana:
  image: docker.elastic.co/kibana/kibana:8.0.0
  ports:
    - "5601:5601"
```

### Application Performance Monitoring

**New Relic**:
```bash
npm install newrelic
# Add to main.ts before any other require
```

**Datadog**:
```bash
npm install dd-trace
# Configure in main.ts
```

---

## SSL/HTTPS Setup

### Using Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot certonly --nginx -d api.moodi.app

# Configure Nginx
sudo nano /etc/nginx/sites-available/moodi-api
```

### Nginx Configuration

```nginx
server {
    listen 80;
    server_name api.moodi.app;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.moodi.app;

    ssl_certificate /etc/letsencrypt/live/api.moodi.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.moodi.app/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /socket.io {
        proxy_pass http://localhost:3000/socket.io;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t moodi-backend:latest .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.REGISTRY_PASSWORD }} | docker login -u ${{ secrets.REGISTRY_USER }} --password-stdin
          docker push moodi-backend:latest
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            cd moodi_mobile_app/backend
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d
            docker-compose -f docker-compose.prod.yml exec -T backend npm run migration:run
```

---

## Scaling Considerations

### Horizontal Scaling

1. **Load Balancer**: Use Nginx, HAProxy, or cloud provider LB
2. **Multiple Backend Instances**: Run multiple NestJS processes
3. **Shared Database**: Single PostgreSQL instance (or replicated)
4. **Shared Cache**: Redis cluster for caching and sessions
5. **Message Queue**: Optional - Bull/RabbitMQ for background jobs

### Vertical Scaling

- Increase server CPU/Memory
- Optimize database queries
- Enable query caching in Redis
- Implement pagination for large datasets

### Database Optimization

```sql
-- Create indexes for frequent queries
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_friends_user_id ON friends(user_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);

-- Vacuum and analyze
VACUUM ANALYZE;
```

---

## Troubleshooting

### Docker Issues

```bash
# Check container logs
docker logs moodi-backend

# Restart container
docker-compose restart backend

# Rebuild image
docker-compose down
docker build -t moodi-backend:latest .
docker-compose up -d
```

### Database Connection Issues

```bash
# Test connection
docker exec moodi-postgres psql -U moodi_user -c "SELECT 1;"

# Check migration status
npm run typeorm migration:show

# Rollback migration
npm run migration:revert
```

### Redis Connection Issues

```bash
# Test Redis
docker exec moodi-redis redis-cli ping

# Clear Redis cache
docker exec moodi-redis redis-cli FLUSHALL
```

### High Memory Usage

```bash
# Check Node process
node --max-old-space-size=2048 dist/main.js

# Monitor memory
docker stats moodi-backend
```

### Slow Queries

```bash
# Enable query logging in .env
DATABASE_LOGGING=true

# Analyze slow queries
EXPLAIN ANALYZE SELECT * FROM posts WHERE created_at > NOW() - INTERVAL '7 days';

# Add indexes if needed
CREATE INDEX idx_posts_date ON posts(created_at DESC);
```

---

## Security Checklist

- [ ] Change all default passwords
- [ ] Enable HTTPS/SSL
- [ ] Configure CORS properly
- [ ] Enable rate limiting
- [ ] Set strong JWT secret
- [ ] Use environment variables for secrets
- [ ] Enable HELMET middleware
- [ ] Setup firewall rules
- [ ] Enable database encryption
- [ ] Regular backups scheduled
- [ ] Monitor error logs
- [ ] Keep dependencies updated
- [ ] Review access logs regularly
- [ ] Setup alerting for failures

---

## Backup & Recovery

### Automated Backups

```bash
#!/bin/bash
# backup.sh - Daily database backup

BACKUP_DIR="/backups"
DB_NAME="moodi_prod"
DB_USER="moodi_user"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup
pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/backup_$TIMESTAMP.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

# Upload to S3
aws s3 cp $BACKUP_DIR/backup_$TIMESTAMP.sql.gz s3://moodi-backups/
```

Schedule with cron:
```bash
0 2 * * * /home/ubuntu/backup.sh
```

### Recovery Procedure

```bash
# Restore from backup
gunzip < backup_20261020_020000.sql.gz | psql -U moodi_user moodi_prod

# Verify data
psql -U moodi_user moodi_prod -c "SELECT COUNT(*) FROM users;"
```

---

## Support & Resources

- **Documentation**: See README.md
- **API Docs**: http://api.moodi.app/docs
- **GitHub**: https://github.com/your-org/moodi
- **Issues**: GitHub Issues tracker
- **Discord**: Join our community channel

---

**Last Updated**: October 20, 2024  
**Version**: 1.0  
**Status**: Production Ready
