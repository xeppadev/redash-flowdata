#!/bin/bash

# Redash Deployment Script for Dokploy
# This script helps you deploy Redash using Docker Compose

set -e

echo "🚀 Redash Deployment Script for Dokploy"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from .env.example...${NC}"
    cp .env.example .env
    echo -e "${RED}🔴 IMPORTANT: Please edit .env file with your production values before deploying!${NC}"
    echo -e "${YELLOW}Required changes in .env:${NC}"
    echo "  - REDASH_HOST: Set your domain"
    echo "  - REDASH_SECRET_KEY: Generate a strong secret key"
    echo "  - REDASH_COOKIE_SECRET: Generate a strong cookie secret"
    echo "  - REDASH_WTF_CSRF_SECRET_KEY: Generate a CSRF secret"
    echo "  - Email settings (if you want email notifications)"
    echo ""
    echo -e "${YELLOW}You can generate secrets using: openssl rand -base64 32${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose > /dev/null 2>&1; then
    if ! docker compose version > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose is not available. Please install Docker Compose.${NC}"
        exit 1
    fi
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo -e "${GREEN}✅ Docker and Docker Compose are available${NC}"

# Function to generate secret key
generate_secret() {
    openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32
}

# Check if secrets are set in .env
echo "🔍 Checking .env configuration..."

if grep -q "your-super-secret-key-here-change-this" .env; then
    echo -e "${YELLOW}⚠️  Generating new secret keys...${NC}"

    # Generate new secrets
    SECRET_KEY=$(generate_secret)
    COOKIE_SECRET=$(generate_secret)
    CSRF_SECRET=$(generate_secret)

    # Replace placeholders
    sed -i.bak "s/your-super-secret-key-here-change-this/$SECRET_KEY/" .env
    sed -i.bak "s/your-cookie-secret-here-change-this/$COOKIE_SECRET/" .env
    sed -i.bak "s/your-csrf-secret-here-change-this/$CSRF_SECRET/" .env

    rm -f .env.bak
    echo -e "${GREEN}✅ Secret keys generated and updated in .env${NC}"
fi

# Check if domain is set
if grep -q "https://your-domain.com" .env; then
    echo -e "${RED}🔴 Please set your domain in REDASH_HOST in .env file${NC}"
    echo "Example: REDASH_HOST=https://redash.yourdomain.com"
    exit 1
fi

echo -e "${GREEN}✅ Environment configuration looks good${NC}"

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p uploads
mkdir -p logs

echo "🏗️  Building and starting services..."

# Pull latest images
$DOCKER_COMPOSE -f docker-compose.prod.yml pull

# Start services
$DOCKER_COMPOSE -f docker-compose.prod.yml up -d

# Wait for services to be ready
echo "⏰ Waiting for services to start..."
sleep 30

# Check if database needs initialization
echo "🗄️  Checking database initialization..."
if $DOCKER_COMPOSE -f docker-compose.prod.yml exec -T server python manage.py database current_revision | grep -q "(empty)"; then
    echo "📊 Initializing database..."
    $DOCKER_COMPOSE -f docker-compose.prod.yml exec -T server python manage.py database create_tables

    echo "👤 Creating admin user..."
    echo -e "${YELLOW}Please provide admin user details:${NC}"
    read -p "Admin email: " ADMIN_EMAIL
    read -s -p "Admin password: " ADMIN_PASSWORD
    echo ""

    $DOCKER_COMPOSE -f docker-compose.prod.yml exec -T server python manage.py users create "$ADMIN_EMAIL" "Admin User" --password "$ADMIN_PASSWORD" --admin
    echo -e "${GREEN}✅ Admin user created${NC}"
else
    echo -e "${GREEN}✅ Database already initialized${NC}"
fi

# Show status
echo ""
echo "📊 Service Status:"
$DOCKER_COMPOSE -f docker-compose.prod.yml ps

echo ""
echo -e "${GREEN}🎉 Redash deployment completed!${NC}"
echo ""
echo "📋 Next steps:"
echo "1. Configure your domain DNS to point to this server"
echo "2. Set up SSL/TLS certificate (recommended: Let's Encrypt)"
echo "3. Configure email settings in .env if needed"
echo "4. Access your Redash instance at the configured domain"
echo ""
echo "🔧 Useful commands:"
echo "  View logs: $DOCKER_COMPOSE -f docker-compose.prod.yml logs -f"
echo "  Stop services: $DOCKER_COMPOSE -f docker-compose.prod.yml down"
echo "  Restart services: $DOCKER_COMPOSE -f docker-compose.prod.yml restart"
echo "  Update: git pull && $DOCKER_COMPOSE -f docker-compose.prod.yml pull && $DOCKER_COMPOSE -f docker-compose.prod.yml up -d"
