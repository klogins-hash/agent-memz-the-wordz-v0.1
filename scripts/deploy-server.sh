#!/bin/bash
# Server deployment script for Agent Memz
# This script is executed on the Hetzner server via SSH

set -e  # Exit on error

echo "🚀 Starting deployment..."

# Configuration
DEPLOY_DIR="/opt/agent-memz"
REPO_URL="https://github.com/klogins-hash/agent-memz-the-wordz-v0.1.git"
BACKUP_DIR="/opt/agent-memz-backups/$(date +%Y%m%d_%H%M%S)"

# Create deployment directory if it doesn't exist
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "📁 Creating deployment directory..."
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR
    git clone $REPO_URL .
else
    echo "📥 Pulling latest changes..."
    cd $DEPLOY_DIR
    git fetch origin
    git reset --hard origin/master
fi

# Create secrets directory FIRST (before any docker commands)
echo "🔐 Setting up Docker secrets..."
mkdir -p $DEPLOY_DIR/secrets
chmod 700 $DEPLOY_DIR/secrets

# Create secret files (only if they don't exist)
if [ ! -f "$DEPLOY_DIR/secrets/postgres_password.txt" ]; then
    echo "${POSTGRES_PASSWORD:-changeme_postgres_$(openssl rand -hex 16)}" > $DEPLOY_DIR/secrets/postgres_password.txt
    chmod 600 $DEPLOY_DIR/secrets/postgres_password.txt
    echo "✓ Created postgres_password secret"
fi

if [ ! -f "$DEPLOY_DIR/secrets/minio_password.txt" ]; then
    echo "${MINIO_ROOT_PASSWORD:-changeme_minio_$(openssl rand -hex 16)}" > $DEPLOY_DIR/secrets/minio_password.txt
    chmod 600 $DEPLOY_DIR/secrets/minio_password.txt
    echo "✓ Created minio_password secret"
fi

if [ ! -f "$DEPLOY_DIR/secrets/cohere_api_key.txt" ]; then
    if [ -n "$COHERE_API_KEY" ]; then
        echo "$COHERE_API_KEY" > $DEPLOY_DIR/secrets/cohere_api_key.txt
        chmod 600 $DEPLOY_DIR/secrets/cohere_api_key.txt
        echo "✓ Created cohere_api_key secret"
    else
        echo "⚠️  COHERE_API_KEY not set - create secrets/cohere_api_key.txt manually"
    fi
fi

if [ ! -f "$DEPLOY_DIR/secrets/grafana_password.txt" ]; then
    echo "${GRAFANA_PASSWORD:-admin_grafana_$(openssl rand -hex 8)}" > $DEPLOY_DIR/secrets/grafana_password.txt
    chmod 600 $DEPLOY_DIR/secrets/grafana_password.txt
    echo "✓ Created grafana_password secret"
fi

# Create minimal .env file (non-sensitive config only)
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "⚙️  Creating .env file..."
    cat > $DEPLOY_DIR/.env << EOF
# PostgreSQL Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=agentmemz
POSTGRES_DB=agent_memory

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# MinIO Configuration
MINIO_ENDPOINT=minio:9000
MINIO_ROOT_USER=minioadmin
MINIO_SECURE=false

# Application Settings
APP_ENV=production
DEBUG=false
LOG_LEVEL=info
EOF
    chmod 600 $DEPLOY_DIR/.env
fi

# Stop existing containers gracefully
if [ "$(docker-compose ps -q)" ]; then
    echo "🛑 Stopping existing containers..."
    docker-compose down --remove-orphans
fi

# Pull latest images
echo "🐳 Pulling Docker images..."
docker-compose pull

# Create the agent network if it doesn't exist
echo "🌐 Ensuring agent-network exists..."
docker network create agent-network 2>/dev/null || echo "Network already exists"

# Build and start main services
echo "🏗️  Building and starting main services..."
docker-compose up -d --build

# Start monitoring stack
echo "📊 Starting monitoring stack..."
docker-compose -f docker-compose.monitoring.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check PostgreSQL health
echo "🔍 Checking PostgreSQL..."
docker-compose exec -T postgres pg_isready -U agentmemz || {
    echo "❌ PostgreSQL is not ready!"
    docker-compose logs postgres
    exit 1
}

# Check Redis health
echo "🔍 Checking Redis..."
docker-compose exec -T redis redis-cli ping || {
    echo "❌ Redis is not ready!"
    docker-compose logs redis
    exit 1
}

# Check MinIO health
echo "🔍 Checking MinIO..."
sleep 5  # Give MinIO a bit more time
docker-compose exec -T minio mc --version > /dev/null 2>&1 || echo "MinIO is starting..."

# Show container status
echo "📊 Container status:"
docker-compose ps

# Clean up old images
echo "🧹 Cleaning up old Docker images..."
docker image prune -f

# Keep only last 5 backups
if [ -d "/opt/agent-memz-backups" ]; then
    echo "🗑️  Cleaning old backups (keeping last 5)..."
    ls -t /opt/agent-memz-backups | tail -n +6 | xargs -I {} rm -rf /opt/agent-memz-backups/{} || true
fi

echo "✅ Deployment completed successfully!"
echo ""
echo "Services are running at:"
echo "  PostgreSQL: localhost:5432"
echo "  Redis: localhost:6379"
echo "  MinIO API: http://37.27.96.88:9000"
echo "  MinIO Console: http://37.27.96.88:9001"
echo ""
echo "Monitoring services:"
echo "  Portainer: https://37.27.96.88:9443"
echo "  Grafana: http://37.27.96.88:3000 (admin / $(cat $DEPLOY_DIR/secrets/grafana_password.txt))"
echo "  Prometheus: http://37.27.96.88:9090"
echo ""
echo "View logs: docker-compose logs -f"
echo "View monitoring logs: docker-compose -f docker-compose.monitoring.yml logs -f"
echo "Stop all services: docker-compose down && docker-compose -f docker-compose.monitoring.yml down"
