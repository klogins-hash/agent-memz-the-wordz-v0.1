#!/bin/bash
set -e

SERVER="root@37.27.96.88"
DEPLOY_PATH="/root/agent-memz-the-wordz-v0.1"

echo "📦 Deploying Airbyte Proxy to $SERVER..."

# Upload files
echo "📤 Uploading configuration files..."
scp docker-compose.airbyte-proxy.yml ${SERVER}:${DEPLOY_PATH}/
scp nginx-airbyte.conf ${SERVER}:${DEPLOY_PATH}/

# Deploy on server
echo "🚀 Starting Airbyte Proxy..."
ssh ${SERVER} << 'EOF'
cd /root/agent-memz-the-wordz-v0.1

# Add Docker extra host for Linux (host.docker.internal doesn't work on Linux by default)
# We need to use the host IP instead
HOST_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')

# Update docker-compose to add extra_hosts for Linux
cat > docker-compose.airbyte-proxy.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  airbyte-proxy:
    image: nginx:alpine
    container_name: airbyte-proxy
    restart: unless-stopped
    networks:
      - coolify
    volumes:
      - ./nginx-airbyte.conf:/etc/nginx/nginx.conf:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.airbyte.rule=Host(`etl.basedaf.ai`)"
      - "traefik.http.routers.airbyte.entrypoints=https"
      - "traefik.http.routers.airbyte.tls=true"
      - "traefik.http.routers.airbyte.tls.certresolver=letsencrypt"
      - "traefik.http.services.airbyte.loadbalancer.server.port=80"
      - "traefik.http.routers.airbyte-http.rule=Host(`etl.basedaf.ai`)"
      - "traefik.http.routers.airbyte-http.entrypoints=http"
      - "traefik.http.routers.airbyte-http.middlewares=https-redirect"
      - "traefik.http.middlewares.https-redirect.redirectscheme.scheme=https"

networks:
  coolify:
    external: true
COMPOSE_EOF

# Stop existing proxy if running
docker-compose -f docker-compose.airbyte-proxy.yml down 2>/dev/null || true

# Start proxy
docker-compose -f docker-compose.airbyte-proxy.yml up -d

echo "✅ Airbyte Proxy deployed successfully!"
echo "🌐 Access Airbyte at: https://etl.basedaf.ai"
echo "📊 Direct access: http://37.27.96.88:8500"

# Show container status
echo ""
echo "Container status:"
docker ps | grep airbyte-proxy || echo "Container not running!"

EOF

echo "✅ Deployment complete!"
echo ""
echo "Access URLs:"
echo "  - HTTPS: https://etl.basedaf.ai"
echo "  - Direct: http://37.27.96.88:8500"
echo ""
echo "Credentials:"
echo "  - Email: [any email]"
echo "  - Password: bHnGdFlnuODl5S3ad5nHfI4RNOO4t4qP"
