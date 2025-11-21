#!/bin/bash
# deploy-sso.sh - Deploy SSO stack with Traefik, OAuth2 Proxy, and monitoring services

set -e  # Exit on error

echo "================================================"
echo "  Agent Memz - SSO Stack Deployment"
echo "================================================"
echo ""

# Check if .env.sso exists
if [ ! -f .env.sso ]; then
    echo "❌ ERROR: .env.sso file not found!"
    echo ""
    echo "Please create .env.sso file with your configuration:"
    echo "  1. Copy the example: cp .env.sso.example .env.sso"
    echo "  2. Edit .env.sso and fill in:"
    echo "     - DOMAIN (your domain name)"
    echo "     - GITHUB_CLIENT_ID (from GitHub OAuth app)"
    echo "     - GITHUB_CLIENT_SECRET (from GitHub OAuth app)"
    echo ""
    echo "See GITHUB_OAUTH_SETUP.md for detailed instructions."
    exit 1
fi

# Load environment variables to validate
source .env.sso

# Validate required variables
echo "🔍 Validating configuration..."
MISSING_VARS=()

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "your-domain.com" ]; then
    MISSING_VARS+=("DOMAIN")
fi

if [ -z "$GITHUB_CLIENT_ID" ] || [ "$GITHUB_CLIENT_ID" = "your_github_client_id_here" ]; then
    MISSING_VARS+=("GITHUB_CLIENT_ID")
fi

if [ -z "$GITHUB_CLIENT_SECRET" ] || [ "$GITHUB_CLIENT_SECRET" = "your_github_client_secret_here" ]; then
    MISSING_VARS+=("GITHUB_CLIENT_SECRET")
fi

if [ -z "$OAUTH2_COOKIE_SECRET" ]; then
    MISSING_VARS+=("OAUTH2_COOKIE_SECRET")
fi

if [ -z "$PORKBUN_API_KEY" ]; then
    MISSING_VARS+=("PORKBUN_API_KEY")
fi

if [ -z "$PORKBUN_SECRET_KEY" ]; then
    MISSING_VARS+=("PORKBUN_SECRET_KEY")
fi

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "❌ ERROR: Missing or invalid configuration variables:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    echo ""
    echo "Please update .env.sso with the correct values."
    echo "See GITHUB_OAUTH_SETUP.md for instructions."
    exit 1
fi

echo "✅ Configuration validated"
echo ""

# Display configuration summary
echo "📋 Configuration Summary:"
echo "   Domain: $DOMAIN"
echo "   GitHub Client ID: ${GITHUB_CLIENT_ID:0:20}..."
echo "   Porkbun API Key: ${PORKBUN_API_KEY:0:20}..."
echo ""

# Check if Docker network exists
echo "🔍 Checking Docker network..."
if ! docker network inspect agent-network >/dev/null 2>&1; then
    echo "⚠️  Creating agent-network..."
    docker network create agent-network
    echo "✅ Network created"
else
    echo "✅ Network exists"
fi
echo ""

# Stop existing SSO services if running
echo "🛑 Stopping existing SSO services (if any)..."
docker-compose -f docker-compose.sso.yml --env-file .env.sso down 2>/dev/null || true
echo ""

# Pull latest images
echo "📥 Pulling latest Docker images..."
docker-compose -f docker-compose.sso.yml --env-file .env.sso pull
echo ""

# Deploy SSO stack
echo "🚀 Deploying SSO stack..."
docker-compose -f docker-compose.sso.yml --env-file .env.sso up -d
echo ""

# Wait for services to start
echo "⏳ Waiting for services to initialize (10 seconds)..."
sleep 10
echo ""

# Check service status
echo "🔍 Checking service status..."
echo ""
docker-compose -f docker-compose.sso.yml --env-file .env.sso ps
echo ""

# Check Traefik health
echo "🔍 Checking Traefik status..."
if docker logs agent-memz-traefik 2>&1 | grep -q "Configuration loaded"; then
    echo "✅ Traefik is running"
else
    echo "⚠️  Traefik may still be starting..."
fi
echo ""

# Check OAuth2 Proxy health
echo "🔍 Checking OAuth2 Proxy status..."
if docker logs agent-memz-oauth2-proxy 2>&1 | grep -q "listening on"; then
    echo "✅ OAuth2 Proxy is running"
else
    echo "⚠️  OAuth2 Proxy may still be starting..."
fi
echo ""

# Display service URLs
echo "================================================"
echo "  🎉 SSO Stack Deployed Successfully!"
echo "================================================"
echo ""
echo "📍 Service URLs (HTTPS with SSO):"
echo "   Dashboard:    https://monitor.$DOMAIN"
echo "   Auth:         https://auth.$DOMAIN"
echo "   Grafana:      https://grafana.$DOMAIN"
echo "   Prometheus:   https://prometheus.$DOMAIN"
echo "   Portainer:    https://portainer.$DOMAIN"
echo "   cAdvisor:     https://cadvisor.$DOMAIN"
echo "   MinIO:        https://minio.$DOMAIN (own auth)"
echo "   Traefik:      https://traefik.$DOMAIN"
echo ""
echo "📍 Traefik Dashboard (local):"
echo "   http://localhost:8090"
echo ""

# Check DNS
echo "🔍 DNS Check:"
echo "   Verifying DNS records for $DOMAIN..."
if nslookup monitor.$DOMAIN >/dev/null 2>&1; then
    echo "   ✅ DNS appears to be configured"
else
    echo "   ⚠️  DNS may not be configured yet"
    echo "   Please add A records pointing to your server IP"
    echo "   See GITHUB_OAUTH_SETUP.md Step 2 for details"
fi
echo ""

# SSL Certificate status
echo "🔐 SSL Certificate Status:"
echo "   Let's Encrypt will provision certificates via Porkbun DNS challenge"
echo "   This may take 1-2 minutes on first deployment"
echo ""
echo "   To check certificate status:"
echo "   docker logs agent-memz-traefik -f | grep -i acme"
echo ""

# Next steps
echo "📝 Next Steps:"
echo "   1. Wait 2-3 minutes for SSL certificates to provision"
echo "   2. Visit https://monitor.$DOMAIN in your browser"
echo "   3. You'll be redirected to GitHub OAuth"
echo "   4. Authorize the app and you'll be logged in"
echo "   5. Use the dashboard toggle to switch between direct/SSO URLs"
echo ""
echo "💡 Troubleshooting:"
echo "   View Traefik logs:      docker logs agent-memz-traefik -f"
echo "   View OAuth2 logs:       docker logs agent-memz-oauth2-proxy -f"
echo "   View all SSO logs:      docker-compose -f docker-compose.sso.yml logs -f"
echo "   Restart services:       docker-compose -f docker-compose.sso.yml --env-file .env.sso restart"
echo ""
echo "📖 Documentation:"
echo "   Full setup guide: GITHUB_OAUTH_SETUP.md"
echo ""
echo "================================================"
