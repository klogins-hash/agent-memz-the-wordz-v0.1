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

# Backup existing data volumes (if they exist)
if [ -d "$DEPLOY_DIR/volumes" ]; then
    echo "💾 Backing up data volumes..."
    mkdir -p $BACKUP_DIR
    docker-compose exec -T postgres pg_dumpall -U agentmemz > $BACKUP_DIR/postgres_backup.sql || true
fi

# Create .env file if it doesn't exist
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "⚙️  Creating .env file..."
    cat > $DEPLOY_DIR/.env << EOF
# PostgreSQL Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=agentmemz
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-devpassword}
POSTGRES_DB=agent_memory

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379

# MinIO Configuration
MINIO_ENDPOINT=minio:9000
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin123}
MINIO_SECURE=false

# OpenAI API Key
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Application Settings
APP_ENV=production
DEBUG=false
LOG_LEVEL=info

# Vector Search Settings
EMBEDDING_MODEL=text-embedding-ada-002
EMBEDDING_DIMENSIONS=1536
SIMILARITY_THRESHOLD=0.7

# Voice Agent Settings
VOICE_SAMPLE_RATE=16000
AUDIO_FORMAT=wav
MAX_AUDIO_SIZE_MB=10
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

# Build and start containers
echo "🏗️  Building and starting containers..."
docker-compose up -d --build

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
echo "View logs: docker-compose logs -f"
echo "Stop services: docker-compose down"
