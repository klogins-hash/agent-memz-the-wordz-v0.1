#!/bin/bash
# Interactive SSO Setup Script
# This script will guide you through the complete SSO setup process

set -e

echo "================================================"
echo "  🚀 Agent Memz - Interactive SSO Setup"
echo "================================================"
echo ""
echo "This script will help you set up GitHub OAuth SSO for your monitoring stack."
echo "We'll need a few pieces of information from you to complete the setup."
echo ""

# Function to read input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local varname="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        eval $varname=\${value:-$default}
    else
        read -p "$prompt: " value
        eval $varname=\"$value\"
    fi
}

# Step 1: Get domain name
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 1: Domain Name"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "You need a domain name for SSL and SSO to work."
echo "Examples: example.com, mysite.io, coolproject.dev"
echo ""
echo "If you don't have a domain yet, you can:"
echo "  - Purchase one from Porkbun.com (recommended, $9-15/year)"
echo "  - Use Namecheap, GoDaddy, Cloudflare, etc."
echo ""

while true; do
    read_with_default "Enter your domain name" "" DOMAIN

    if [ -z "$DOMAIN" ]; then
        echo "❌ Domain cannot be empty!"
        continue
    fi

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid domain format. Examples: example.com, site.io"
        continue
    fi

    echo ""
    echo "✅ Domain: $DOMAIN"
    echo ""
    read -p "Is this correct? (yes/no): " confirm
    if [[ "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        break
    fi
done

# Step 2: GitHub OAuth App Setup
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 2: GitHub OAuth App"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Now you need to create a GitHub OAuth App."
echo ""
echo "📋 Follow these steps:"
echo ""
echo "1. Open this URL in your browser:"
echo "   https://github.com/settings/developers"
echo ""
echo "2. Click 'OAuth Apps' → 'New OAuth App'"
echo ""
echo "3. Fill in the form with these EXACT values:"
echo "   ┌─────────────────────────────────────────────────┐"
echo "   │ Application name:  Agent Memz Monitoring        │"
echo "   │ Homepage URL:      https://$DOMAIN"
echo "   │ Callback URL:      https://auth.$DOMAIN/oauth2/callback"
echo "   │ Description:       (optional)                   │"
echo "   └─────────────────────────────────────────────────┘"
echo ""
echo "4. Click 'Register application'"
echo ""
echo "5. On the app page, click 'Generate a new client secret'"
echo ""
echo "6. Copy BOTH the Client ID and Client Secret"
echo "   ⚠️  You won't be able to see the secret again!"
echo ""

read -p "Press ENTER when you've created the OAuth app and have the credentials ready..."

echo ""
echo "Now enter your GitHub OAuth credentials:"
echo ""

while true; do
    read_with_default "GitHub Client ID" "" GITHUB_CLIENT_ID

    if [ -z "$GITHUB_CLIENT_ID" ]; then
        echo "❌ Client ID cannot be empty!"
        continue
    fi

    if [ ${#GITHUB_CLIENT_ID} -lt 20 ]; then
        echo "⚠️  That seems too short for a Client ID. Are you sure?"
        read -p "Continue anyway? (yes/no): " confirm
        if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            continue
        fi
    fi
    break
done

echo ""

while true; do
    read_with_default "GitHub Client Secret" "" GITHUB_CLIENT_SECRET

    if [ -z "$GITHUB_CLIENT_SECRET" ]; then
        echo "❌ Client Secret cannot be empty!"
        continue
    fi

    if [ ${#GITHUB_CLIENT_SECRET} -lt 30 ]; then
        echo "⚠️  That seems too short for a Client Secret. Are you sure?"
        read -p "Continue anyway? (yes/no): " confirm
        if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            continue
        fi
    fi
    break
done

# Step 3: Create .env.sso file
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 3: Creating Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Read existing values from .env.sso.example
OAUTH2_COOKIE_SECRET=$(grep OAUTH2_COOKIE_SECRET .env.sso.example | cut -d'=' -f2)
PORKBUN_API_KEY=$(grep PORKBUN_API_KEY .env.sso.example | cut -d'=' -f2)
PORKBUN_SECRET_KEY=$(grep PORKBUN_SECRET_KEY .env.sso.example | cut -d'=' -f2)

echo "Creating .env.sso file..."

cat > .env.sso << EOF
# SSO Configuration for Agent Memz Monitoring Stack
# Generated on $(date)

# Domain Configuration
DOMAIN=$DOMAIN

# GitHub OAuth Application Credentials
GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET

# OAuth2 Proxy Cookie Secret (auto-generated)
OAUTH2_COOKIE_SECRET=$OAUTH2_COOKIE_SECRET

# Porkbun DNS API Credentials (for Let's Encrypt)
PORKBUN_API_KEY=$PORKBUN_API_KEY
PORKBUN_SECRET_KEY=$PORKBUN_SECRET_KEY
EOF

echo "✅ .env.sso created"
echo ""

# Step 4: Configure DNS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 4: DNS Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "You need to configure DNS records for your domain."
echo ""
echo "Required DNS Records (A Records):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Type    Host              Value           TTL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "A       *                 37.27.96.88     600    (wildcard)"
echo "OR these individual records:"
echo "A       @                 37.27.96.88     600"
echo "A       monitor           37.27.96.88     600"
echo "A       auth              37.27.96.88     600"
echo "A       grafana           37.27.96.88     600"
echo "A       prometheus        37.27.96.88     600"
echo "A       portainer         37.27.96.88     600"
echo "A       cadvisor          37.27.96.88     600"
echo "A       minio             37.27.96.88     600"
echo "A       traefik           37.27.96.88     600"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "How to add these records:"
echo ""
echo "If domain is on Porkbun:"
echo "  1. Log in to https://porkbun.com/account/domainsSpeedy"
echo "  2. Click 'DNS' next to $DOMAIN"
echo "  3. Add the records above"
echo ""
echo "If domain is elsewhere:"
echo "  - Log in to your domain registrar"
echo "  - Find DNS settings"
echo "  - Add the A records listed above"
echo ""

read -p "Have you configured the DNS records? (yes/no): " dns_configured

if [[ ! "$dns_configured" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo ""
    echo "⚠️  Please configure DNS before deploying."
    echo "   DNS propagation can take 5-15 minutes."
    echo ""
    echo "Once DNS is configured, run:"
    echo "  ./scripts/deploy-sso.sh"
    echo ""
    exit 0
fi

# Step 5: Deploy
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 5: Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ready to deploy the SSO stack!"
echo ""
echo "This will:"
echo "  ✓ Upload configuration to server (37.27.96.88)"
echo "  ✓ Deploy Traefik reverse proxy"
echo "  ✓ Deploy OAuth2 Proxy"
echo "  ✓ Deploy all monitoring services with HTTPS"
echo "  ✓ Provision SSL certificates via Let's Encrypt"
echo ""

read -p "Deploy now? (yes/no): " deploy_now

if [[ "$deploy_now" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo ""
    echo "🚀 Deploying SSO stack..."
    echo ""

    # Upload files to server
    echo "📤 Uploading configuration files..."
    scp .env.sso docker-compose.sso.yml scripts/deploy-sso.sh root@37.27.96.88:/root/agent-memz-the-wordz-v0.1/ || {
        echo "❌ Failed to upload files. Check SSH access to root@37.27.96.88"
        exit 1
    }

    # Upload updated dashboard
    echo "📤 Uploading dashboard..."
    scp -r monitoring/dashboard root@37.27.96.88:/root/agent-memz-the-wordz-v0.1/monitoring/ || {
        echo "⚠️  Warning: Could not upload dashboard"
    }

    echo ""
    echo "🔗 Connecting to server and deploying..."
    echo ""

    # Deploy on server
    ssh root@37.27.96.88 "cd /root/agent-memz-the-wordz-v0.1 && bash scripts/deploy-sso.sh"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎉 DEPLOYMENT COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🌐 Your services are now available at:"
    echo ""
    echo "  Dashboard:    https://monitor.$DOMAIN"
    echo "  Grafana:      https://grafana.$DOMAIN"
    echo "  Prometheus:   https://prometheus.$DOMAIN"
    echo "  Portainer:    https://portainer.$DOMAIN"
    echo "  cAdvisor:     https://cadvisor.$DOMAIN"
    echo "  MinIO:        https://minio.$DOMAIN"
    echo ""
    echo "🔐 Authentication:"
    echo "  - All services protected by GitHub OAuth SSO"
    echo "  - Login once, access everything!"
    echo ""
    echo "⏱️  Note: SSL certificates may take 1-2 minutes to provision"
    echo ""
    echo "📖 Documentation: GITHUB_OAUTH_SETUP.md"
    echo ""
else
    echo ""
    echo "Configuration saved to .env.sso"
    echo ""
    echo "To deploy later, run:"
    echo "  ./scripts/deploy-sso.sh"
    echo ""
fi
