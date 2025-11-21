#!/bin/bash

# Airbyte ETL Deployment Script
# Deploys Airbyte with multitenancy support to Hetzner server

set -e

SERVER_IP="37.27.96.88"
SERVER_USER="root"
DEPLOY_DIR="/root/agent-memz-the-wordz-v0.1"

echo "==================================="
echo "Airbyte ETL Deployment"
echo "==================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if .env.airbyte exists
if [ ! -f ".env.airbyte" ]; then
    echo -e "${RED}Error: .env.airbyte file not found!${NC}"
    echo "Please create .env.airbyte with required configuration."
    exit 1
fi

echo -e "${YELLOW}Step 1: Uploading Airbyte configuration files...${NC}"
scp docker-compose.airbyte.yml ${SERVER_USER}@${SERVER_IP}:${DEPLOY_DIR}/
scp .env.airbyte ${SERVER_USER}@${SERVER_IP}:${DEPLOY_DIR}/
scp scripts/init-airbyte-db.sql ${SERVER_USER}@${SERVER_IP}:${DEPLOY_DIR}/scripts/
echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

echo -e "${YELLOW}Step 2: Initializing Airbyte database...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
cd /root/agent-memz-the-wordz-v0.1

# Get PostgreSQL password from .env.airbyte
POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env.airbyte | cut -d '=' -f2)

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
docker exec agent-memz-postgres pg_isready -U agentmemz || {
    echo "Error: PostgreSQL is not running!"
    exit 1
}

# Run database initialization
echo "Creating Airbyte database and schema..."
docker exec -i agent-memz-postgres psql -U agentmemz -d postgres < scripts/init-airbyte-db.sql

echo "✓ Database initialized"
ENDSSH
echo -e "${GREEN}✓ Database ready${NC}"
echo ""

echo -e "${YELLOW}Step 3: Deploying Airbyte stack...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
cd /root/agent-memz-the-wordz-v0.1

# Stop any existing Airbyte containers
echo "Stopping existing Airbyte containers (if any)..."
docker compose -f docker-compose.airbyte.yml --env-file .env.airbyte down 2>/dev/null || true

# Pull latest images
echo "Pulling Airbyte images..."
docker compose -f docker-compose.airbyte.yml --env-file .env.airbyte pull

# Start Airbyte stack
echo "Starting Airbyte stack..."
docker compose -f docker-compose.airbyte.yml --env-file .env.airbyte up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 15

# Check status
echo ""
echo "Container status:"
docker compose -f docker-compose.airbyte.yml ps

ENDSSH
echo -e "${GREEN}✓ Airbyte stack deployed${NC}"
echo ""

echo -e "${YELLOW}Step 4: Verifying deployment...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
cd /root/agent-memz-the-wordz-v0.1

# Check container health
echo "Checking Airbyte containers..."
for container in agent-memz-airbyte-server agent-memz-airbyte-webapp agent-memz-airbyte-worker agent-memz-airbyte-temporal; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "✓ ${container} is running"
    else
        echo "✗ ${container} is NOT running"
    fi
done

# Check logs for errors
echo ""
echo "Recent Airbyte server logs:"
docker logs agent-memz-airbyte-server --tail 20 2>&1 | grep -v "INFO" | head -10 || echo "No errors detected"

ENDSSH
echo -e "${GREEN}✓ Verification complete${NC}"
echo ""

echo "==================================="
echo -e "${GREEN}Airbyte Deployment Complete!${NC}"
echo "==================================="
echo ""
echo "Access Airbyte at:"
echo "  🌐 https://etl.basedaf.ai"
echo ""
echo "Default credentials:"
echo "  Email: airbyte@example.com"
echo "  Password: password"
echo ""
echo "Next steps:"
echo "  1. Visit https://etl.basedaf.ai"
echo "  2. Log in with default credentials"
echo "  3. Change the password immediately"
echo "  4. Create workspaces for each tenant"
echo "  5. Configure your first data source and destination"
echo ""
echo "To view logs:"
echo "  ssh root@${SERVER_IP}"
echo "  cd ${DEPLOY_DIR}"
echo "  docker compose -f docker-compose.airbyte.yml logs -f"
echo ""
