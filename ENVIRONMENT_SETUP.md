# Environment Setup Guide

Complete guide for setting up the Moodi development environment locally.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Backend Setup](#backend-setup)
3. [Flutter Setup](#flutter-setup)
4. [Environment Variables](#environment-variables)
5. [Database Setup](#database-setup)
6. [Testing Setup](#testing-setup)
7. [Common Issues](#common-issues)

---

## System Requirements

### Minimum Hardware
- **CPU**: 4 cores (8 recommended)
- **RAM**: 8 GB (16 GB recommended)
- **Disk**: 20 GB free space
- **Network**: Stable internet connection

### macOS Setup

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node@18

# Install Flutter
brew install flutter

# Install Docker
brew install --cask docker

# Install PostgreSQL (optional, use Docker instead)
brew install postgresql

# Install Redis (optional, use Docker instead)
brew install redis

# Install Git
brew install git
```

### Windows Setup

1. **Node.js**: Download from https://nodejs.org/ (v18 LTS)
2. **Git**: Download from https://git-scm.com/
3. **Docker Desktop**: Download from https://www.docker.com/products/docker-desktop
4. **Flutter**: Download from https://flutter.dev/docs/get-started/install/windows
5. **Android Studio**: Download from https://developer.android.com/studio

### Linux (Ubuntu/Debian)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$(pwd)/flutter/bin"' >> ~/.bashrc

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install Redis
sudo apt install -y redis-server
```

---

## Backend Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/moodi.git
cd moodi/backend
```

### 2. Install Dependencies

```bash
# Install Node dependencies
npm install --legacy-peer-deps

# Verify installation
npm list | head -20
```

### 3. Environment Configuration

Create `.env` file in `backend/` directory:

```bash
cp .env.example .env
```

Edit `.env`:

```env
# ============ Core ============
NODE_ENV=development
API_PORT=3000
API_URL=http://localhost:3000

# ============ Database ============
DATABASE_TYPE=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=moodi_dev
DATABASE_USER=moodi_user
DATABASE_PASSWORD=moodi_password_123
DATABASE_SYNCHRONIZE=true
DATABASE_LOGGING=true

# ============ Redis ============
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password_123
REDIS_DB=0

# ============ JWT ============
JWT_SECRET=your_jwt_secret_key_min_32_chars_dev_key
JWT_EXPIRY=24h
REFRESH_TOKEN_EXPIRY=7d

# ============ CORS ============
CORS_ORIGIN=http://localhost:3000,http://localhost:8080,http://localhost:8081
CORS_CREDENTIALS=true

# ============ Logging ============
LOG_LEVEL=debug
LOG_FORMAT=text

# ============ File Storage ============
STORAGE_MAX_FILE_SIZE=10485760
STORAGE_ALLOWED_TYPES=image/jpeg,image/png,image/webp,video/mp4
```

### 4. Start Services

```bash
# Start PostgreSQL and Redis with Docker Compose
docker-compose up -d

# Verify services
docker-compose ps

# Expected output:
# NAME         STATUS       PORTS
# postgres     Up 2 minutes 0.0.0.0:5432->5432/tcp
# redis        Up 2 minutes 0.0.0.0:6379->6379/tcp
# adminer      Up 2 minutes 0.0.0.0:8080->8080/tcp
```

### 5. Initialize Database

```bash
# Run migrations
npm run migration:run

# Seed test data
npm run seed

# Check database
npm run typeorm migration:show
```

### 6. Start Development Server

```bash
# Terminal 1: Start backend
npm run start:dev

# Expected output:
# [Nest] ... - 10/20/2024, 10:30:00 AM     LOG [NestFactory] Starting Nest application...
# [Nest] ... - 10/20/2024, 10:30:02 AM     LOG [InstanceLoader] AppModule dependencies initialized
# [Nest] ... - 10/20/2024, 10:30:02 AM     LOG [NestApplication] Nest application successfully started

# Server running on: http://localhost:3000
# Swagger API docs: http://localhost:3000/docs
```

### 7. Test Backend

```bash
# In a new terminal, test API
curl http://localhost:3000/health

# Expected response:
# {"status":"ok","timestamp":"2024-10-20T10:30:00Z","database":"connected"}
```

---

## Flutter Setup

### 1. Install Flutter SDK

```bash
# macOS/Linux
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter doctor

# Expected output shows all checks should have ✓
```

### 2. Setup Android Development

```bash
# Install Android SDK
flutter config --android-sdk /path/to/android/sdk

# Accept Android licenses
flutter doctor --android-licenses

# Verify setup
flutter doctor
```

### 3. Setup iOS Development (macOS only)

```bash
# Install CocoaPods
sudo gem install cocoapods

# Verify setup
flutter doctor -v
```

### 4. Clone Flutter App

```bash
cd moodi
```

### 5. Install Flutter Dependencies

```bash
# Get packages
flutter pub get

# Generate build files
flutter pub run build_runner build

# Verify
flutter pub deps
```

### 6. Configure API Endpoint

Edit `lib/core/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
  static const String apiVersion = '';  // Empty for localhost
  
  // ... rest of configuration
}
```

### 7. Run Flutter App

```bash
# iOS (macOS only)
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome

# All devices
flutter devices
flutter run
```

---

## Environment Variables

### Backend .env Example

**Development**:
```env
NODE_ENV=development
API_PORT=3000
DATABASE_HOST=localhost
DATABASE_PASSWORD=moodi_password_123
REDIS_PASSWORD=redis_password_123
JWT_SECRET=dev_secret_key_at_least_32_chars_long_min
LOG_LEVEL=debug
```

**Testing**:
```env
NODE_ENV=testing
API_PORT=3001
DATABASE_NAME=moodi_test
DATABASE_PASSWORD=test_password
REDIS_DB=1
LOG_LEVEL=warn
```

**Production**:
```env
NODE_ENV=production
API_PORT=3000
DATABASE_HOST=prod-db.rds.amazonaws.com
DATABASE_PASSWORD=${DB_PASSWORD_SECRET}
JWT_SECRET=${JWT_SECRET_FROM_VAULT}
LOG_LEVEL=warn
ENABLE_HELMET=true
```

### Flutter Configuration

Edit `lib/core/api_config.dart` for environment:

```dart
class ApiConfig {
  // Development
  static const String baseUrl = 'http://localhost:3000';
  
  // Or Production
  // static const String baseUrl = 'https://api.moodi.app';
  
  // Endpoints
  static const String authLogin = '$baseUrl/auth/login';
  static const String authRegister = '$baseUrl/auth/register';
  static const String refreshToken = '$baseUrl/auth/refresh';
  
  // ... more endpoints
}
```

---

## Database Setup

### Initial Setup (First Time)

```bash
# 1. Start services
docker-compose up -d

# 2. Create database schema
docker exec moodi-postgres psql -U moodi_user -d moodi_dev -c "CREATE SCHEMA IF NOT EXISTS public;"

# 3. Run migrations
npm run migration:run

# 4. Seed sample data
npm run seed

# 5. Verify
npm run typeorm migration:show
```

### Creating a New Migration

```bash
# 1. Modify entity file (src/database/entities/*)
# 2. Generate migration
npm run migration:generate -- -n DescriptionOfChange

# 3. Review generated file in src/database/migrations/
# 4. Run migration
npm run migration:run
```

### Database Access

**Via Docker**:
```bash
# Interactive PostgreSQL terminal
docker exec -it moodi-postgres psql -U moodi_user -d moodi_dev

# Sample queries
SELECT * FROM users;
SELECT COUNT(*) FROM posts;
\dt  # List all tables
```

**Via Adminer Web UI**:
- Open http://localhost:8080
- Server: postgres
- Username: moodi_user
- Password: moodi_password_123
- Database: moodi_dev

**Via pgAdmin** (Optional):
```bash
# Add to docker-compose.yml
pgadmin:
  image: dpage/pgadmin4:latest
  environment:
    PGADMIN_DEFAULT_EMAIL: admin@moodi.app
    PGADMIN_DEFAULT_PASSWORD: admin123
  ports:
    - "5050:80"
```

### Resetting Database

```bash
# WARNING: This deletes all data!

# Option 1: Drop and recreate
docker exec moodi-postgres psql -U moodi_user -c "DROP DATABASE IF EXISTS moodi_dev;"
docker exec moodi-postgres psql -U moodi_user -c "CREATE DATABASE moodi_dev;"
npm run migration:run
npm run seed

# Option 2: Delete volumes (complete reset)
docker-compose down -v
docker-compose up -d
npm run migration:run
npm run seed
```

---

## Testing Setup

### Backend Tests

```bash
# Run unit tests
npm run test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:cov

# Run E2E tests
npm run test:e2e
```

### Flutter Tests

```bash
# Run unit tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart

# Generate coverage report
lcov --list coverage/lcov.info
```

---

## Git Setup

### Configure Git

```bash
# Set user info
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Setup SSH key (optional)
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub  # Copy to GitHub settings

# Test connection
ssh -T git@github.com
```

### Common Git Workflow

```bash
# Clone repository
git clone git@github.com:your-org/moodi.git

# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ...

# Stage and commit
git add .
git commit -m "feat: add new feature"

# Push branch
git push origin feature/new-feature

# Create pull request on GitHub
```

---

## IDE Setup

### Visual Studio Code

**Extensions**:
- Dart
- Flutter
- REST Client
- PostgreSQL
- Thunder Client

**Settings** (`.vscode/settings.json`):
```json
{
  "dart.flutterSdkPath": "/path/to/flutter",
  "dart.enableSdkFormatter": true,
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll": true
    }
  }
}
```

### Android Studio / IntelliJ

**Plugins**:
- Flutter
- Dart
- Database Navigator

### Xcode (macOS)

```bash
# Install latest Xcode Command Line Tools
xcode-select --install

# Accept license
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

---

## Common Issues

### Issue: Docker Container Won't Start

```bash
# Check logs
docker logs moodi-postgres

# Rebuild container
docker-compose down -v
docker-compose up -d

# Check port availability
lsof -i :5432
```

### Issue: PostgreSQL Connection Refused

```bash
# Verify container is running
docker ps | grep postgres

# Check network
docker network ls
docker network inspect moodi_default

# Restart services
docker-compose restart postgres redis
```

### Issue: Node Dependencies Error

```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --legacy-peer-deps
```

### Issue: Flutter Not Finding SDK

```bash
# Check Flutter setup
flutter doctor

# Update PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify
which flutter
flutter --version
```

### Issue: Android SDK Not Found

```bash
# Install SDK components
flutter config --android-sdk /usr/local/share/android-sdk

# Accept licenses
flutter doctor --android-licenses

# Verify
flutter doctor -v
```

### Issue: iOS Build Fails

```bash
# Clean build
flutter clean
cd ios && pod deintegrate && cd ..

# Reinstall pods
flutter pub get
flutter build ios --verbose

# Check Xcode
open ios/Runner.xcworkspace
```

### Issue: Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>

# Or use different port
API_PORT=3001 npm run start:dev
```

### Issue: JWT Token Error

```bash
# Regenerate JWT secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Update .env
JWT_SECRET=<new_generated_secret>

# Restart server
npm run start:dev
```

---

## Performance Optimization

### Backend

```bash
# Enable compression in .env
ENABLE_COMPRESSION=true

# Increase Node memory
node --max-old-space-size=2048 dist/main.js

# Monitor performance
npm run profiler
```

### Flutter

```bash
# Run in release mode (faster)
flutter run --release

# Profile app performance
flutter run --profile

# Check frame rate
flutter run -v | grep "Frame"
```

### Database

```bash
# Add indexes for common queries
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at DESC);

# Analyze query performance
EXPLAIN ANALYZE SELECT * FROM posts WHERE user_id = 1;
```

---

## Security Best Practices

### Development

- [ ] Use `.env.example` template, never commit `.env`
- [ ] Change default database password
- [ ] Generate strong JWT secret
- [ ] Enable CORS only for localhost during dev
- [ ] Use `--no-save` flag for dev dependencies

### Before Deployment

- [ ] Rotate all secrets
- [ ] Update dependencies
- [ ] Run security audit: `npm audit`
- [ ] Review environment variables
- [ ] Enable HTTPS/SSL
- [ ] Setup rate limiting
- [ ] Configure proper CORS

---

## Quick Reference

### Useful Commands

```bash
# Backend
npm run start:dev          # Start dev server
npm run build              # Build for production
npm run test               # Run tests
npm run migration:run      # Run migrations
npm run seed               # Seed database

# Flutter
flutter pub get            # Install dependencies
flutter run                # Run app
flutter test               # Run tests
flutter build apk          # Build Android APK

# Docker
docker-compose up -d       # Start services
docker-compose down        # Stop services
docker-compose logs -f     # View logs
```

### Environment Checklist

- [ ] Node.js v18+ installed
- [ ] Flutter SDK installed
- [ ] Docker & Docker Compose running
- [ ] PostgreSQL container running
- [ ] Redis container running
- [ ] `.env` file configured
- [ ] Migrations run
- [ ] Test data seeded
- [ ] Backend starts without errors
- [ ] Flutter app builds successfully

---

**Last Updated**: October 20, 2024  
**Maintained by**: Development Team  
**Status**: Updated for Production Setup
