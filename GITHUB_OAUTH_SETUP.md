# GitHub OAuth Setup Guide

This guide will walk you through setting up GitHub OAuth for SSO authentication across all monitoring services.

## Prerequisites

- A domain name (e.g., `example.com`)
- Domain DNS configured to point to your server (37.27.96.88)
- Porkbun API credentials (already configured)
- GitHub account

## Step 1: Create GitHub OAuth App

1. **Go to GitHub Settings**
   - Navigate to https://github.com/settings/developers
   - Click "OAuth Apps" in the left sidebar
   - Click "New OAuth App"

2. **Configure OAuth App**
   - **Application name**: `Agent Memz Monitoring` (or any name you prefer)
   - **Homepage URL**: `https://YOUR_DOMAIN` (replace with your actual domain)
   - **Authorization callback URL**: `https://auth.YOUR_DOMAIN/oauth2/callback`
   - **Application description**: (optional) `SSO for monitoring stack`

3. **Register Application**
   - Click "Register application"

4. **Generate Client Secret**
   - After registration, click "Generate a new client secret"
   - **IMPORTANT**: Copy both the **Client ID** and **Client Secret** immediately
   - You won't be able to see the client secret again!

## Step 2: Configure DNS Records

Add the following DNS records to your domain in Porkbun:

### A Records (or use wildcard)
```
Type    Host                Value           TTL
A       @                   37.27.96.88     600
A       *.                  37.27.96.88     600  (wildcard for all subdomains)
```

Or individual records:
```
A       monitor             37.27.96.88     600
A       auth                37.27.96.88     600
A       grafana             37.27.96.88     600
A       prometheus          37.27.96.88     600
A       portainer           37.27.96.88     600
A       cadvisor            37.27.96.88     600
A       minio               37.27.96.88     600
A       traefik             37.27.96.88     600
```

**Wait 5-10 minutes for DNS propagation**

You can verify DNS with:
```bash
nslookup monitor.YOUR_DOMAIN
nslookup auth.YOUR_DOMAIN
```

## Step 3: Create .env.sso File

1. Copy the example file:
```bash
cp .env.sso.example .env.sso
```

2. Edit `.env.sso` with your values:
```bash
nano .env.sso
```

3. Fill in the required values:
   - `DOMAIN`: Your domain name (e.g., `example.com`)
   - `GITHUB_CLIENT_ID`: From GitHub OAuth app (Step 1)
   - `GITHUB_CLIENT_SECRET`: From GitHub OAuth app (Step 1)
   - `OAUTH2_COOKIE_SECRET`: Already generated for you
   - `PORKBUN_API_KEY`: Already filled in
   - `PORKBUN_SECRET_KEY`: Already filled in

## Step 4: Deploy SSO Stack

1. **Upload configuration to server**:
```bash
scp .env.sso root@37.27.96.88:/root/agent-memz-the-wordz-v0.1/
scp docker-compose.sso.yml root@37.27.96.88:/root/agent-memz-the-wordz-v0.1/
```

2. **SSH into server**:
```bash
ssh root@37.27.96.88
cd /root/agent-memz-the-wordz-v0.1
```

3. **Deploy the SSO stack**:
```bash
docker-compose --env-file .env.sso -f docker-compose.sso.yml up -d
```

4. **Check logs**:
```bash
# Watch all SSO services
docker-compose -f docker-compose.sso.yml logs -f

# Check specific services
docker logs agent-memz-traefik -f
docker logs agent-memz-oauth2-proxy -f
```

## Step 5: Verify SSL Certificates

Let's Encrypt will automatically provision SSL certificates via Porkbun DNS challenge. This may take 1-2 minutes.

**Check certificate status**:
```bash
# View Traefik logs for certificate provisioning
docker logs agent-memz-traefik 2>&1 | grep -i acme

# Check acme.json file
docker exec agent-memz-traefik cat /letsencrypt/acme.json
```

## Step 6: Test SSO Authentication

1. **Access the dashboard**:
   - Navigate to `https://monitor.YOUR_DOMAIN` or `https://YOUR_DOMAIN`

2. **GitHub OAuth Flow**:
   - You'll be redirected to `https://auth.YOUR_DOMAIN`
   - Click "Sign in with GitHub"
   - Authorize the application
   - You'll be redirected back to the dashboard

3. **Test other services**:
   - `https://grafana.YOUR_DOMAIN` - Grafana dashboards
   - `https://prometheus.YOUR_DOMAIN` - Prometheus metrics
   - `https://portainer.YOUR_DOMAIN` - Docker management
   - `https://cadvisor.YOUR_DOMAIN` - Container stats
   - `https://minio.YOUR_DOMAIN` - MinIO console (has own auth)
   - `https://traefik.YOUR_DOMAIN` - Traefik dashboard

4. **SSO Cookie Verification**:
   - After logging in once via GitHub, you should be authenticated across ALL subdomains
   - Cookie is set on `.YOUR_DOMAIN` domain
   - No need to login again when accessing different services

## Troubleshooting

### DNS Issues
```bash
# Check DNS propagation
dig monitor.YOUR_DOMAIN
nslookup auth.YOUR_DOMAIN
```

### SSL Certificate Issues
```bash
# Check Traefik logs
docker logs agent-memz-traefik -f

# Common issues:
# - DNS records not propagated (wait 10-15 minutes)
# - Porkbun API credentials incorrect
# - Domain not pointing to correct IP
```

### OAuth Issues
```bash
# Check OAuth2 Proxy logs
docker logs agent-memz-oauth2-proxy -f

# Common issues:
# - Wrong callback URL in GitHub OAuth app
# - Client ID/Secret mismatch
# - Cookie domain misconfigured
```

### Port Conflicts
If you get port conflicts (80, 443 already in use):
```bash
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443

# If Coolify or other services are using them, you'll need to:
# 1. Stop those services temporarily, OR
# 2. Reconfigure Traefik to use alternate ports
```

## Security Notes

1. **Cookie Secret**: The `OAUTH2_COOKIE_SECRET` must be kept secret and never committed to git
2. **Client Secret**: The GitHub client secret should never be committed to git
3. **HTTPS Only**: All services are forced to HTTPS via Traefik redirect
4. **Secure Cookies**: Cookies are marked as secure and httpOnly
5. **Access Control**: Only GitHub-authenticated users can access services

## Service URLs

After setup, access your services at:

| Service | URL | Protected by SSO |
|---------|-----|------------------|
| Dashboard | `https://monitor.YOUR_DOMAIN` | ✅ Yes |
| OAuth Login | `https://auth.YOUR_DOMAIN` | N/A |
| Grafana | `https://grafana.YOUR_DOMAIN` | ✅ Yes |
| Prometheus | `https://prometheus.YOUR_DOMAIN` | ✅ Yes |
| Portainer | `https://portainer.YOUR_DOMAIN` | ✅ Yes |
| cAdvisor | `https://cadvisor.YOUR_DOMAIN` | ✅ Yes |
| MinIO | `https://minio.YOUR_DOMAIN` | ❌ No (own auth) |
| Traefik | `https://traefik.YOUR_DOMAIN` | ✅ Yes |

## Next Steps

1. Set up Grafana dashboards for monitoring
2. Configure Prometheus alert rules
3. Set up email notifications for alerts
4. Configure Grafana auth proxy to auto-create users from GitHub email
5. Add additional GitHub organization restrictions if needed

## Advanced: Restrict to GitHub Organization

To restrict access to members of your GitHub organization:

Edit `.env.sso` and add:
```bash
GITHUB_ORG=your-org-name
```

Then update the oauth2-proxy command in `docker-compose.sso.yml`:
```yaml
command:
  - --github-org=${GITHUB_ORG}
  - --github-team=  # Optional: restrict to specific team
```

Redeploy:
```bash
docker-compose --env-file .env.sso -f docker-compose.sso.yml up -d oauth2-proxy
```
