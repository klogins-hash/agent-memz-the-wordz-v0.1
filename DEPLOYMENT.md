# Deployment Guide

This guide explains how to set up automatic deployment to your Hetzner server.

## Overview

The deployment system uses **GitHub Actions** to automatically deploy code to your Hetzner server whenever you push to the `master` branch.

**Flow:**
```
Git Push → GitHub Actions → SSH to Server → Pull Code → Docker Compose Up
```

## Initial Server Setup

### 1. Prepare SSH Access

First, generate an SSH key pair for GitHub Actions:

```bash
# Generate SSH key (do this on your local machine)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/agent-memz-deploy

# This creates two files:
# ~/.ssh/agent-memz-deploy       (private key - for GitHub Secrets)
# ~/.ssh/agent-memz-deploy.pub   (public key - for server)
```

### 2. Add Public Key to Server

Copy the public key to your Hetzner server:

```bash
# Method 1: Using ssh-copy-id
ssh-copy-id -i ~/.ssh/agent-memz-deploy.pub root@37.27.96.88

# Method 2: Manual copy
cat ~/.ssh/agent-memz-deploy.pub | ssh root@37.27.96.88 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Or manually add it:

```bash
# SSH into your server
ssh root@37.27.96.88

# Add the public key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste the contents of agent-memz-deploy.pub
# Save and exit (Ctrl+X, Y, Enter)
chmod 600 ~/.ssh/authorized_keys
```

### 3. Configure GitHub Secrets

Go to your GitHub repository:
`https://github.com/klogins-hash/agent-memz-the-wordz-v0.1/settings/secrets/actions`

Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SSH_PRIVATE_KEY` | Contents of `~/.ssh/agent-memz-deploy` | Private SSH key for deployment |
| `SERVER_HOST` | `37.27.96.88` | Your Hetzner server IP |
| `SERVER_USER` | `root` | SSH username |
| `OPENAI_API_KEY` | Your OpenAI API key | For embeddings generation |
| `POSTGRES_PASSWORD` | Strong password | PostgreSQL password |
| `MINIO_ROOT_PASSWORD` | Strong password | MinIO admin password |

**To get the private key content:**
```bash
cat ~/.ssh/agent-memz-deploy
# Copy the entire output including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... key content ...
# -----END OPENSSH PRIVATE KEY-----
```

### 4. Initial Server Configuration

SSH into your server and install required software:

```bash
# SSH to server
ssh root@37.27.96.88

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt install docker-compose -y

# Verify installation
docker --version
docker-compose --version

# Create deployment directory
mkdir -p /opt/agent-memz
mkdir -p /opt/agent-memz-backups

# Clone repository manually for first time
cd /opt/agent-memz
git clone https://github.com/klogins-hash/agent-memz-the-wordz-v0.1.git .

# Make scripts executable
chmod +x scripts/*.sh

# Exit server
exit
```

## Testing the Deployment

### Manual Deployment Test

Before relying on automatic deployment, test manually:

```bash
# From your local machine, test SSH access
ssh -i ~/.ssh/agent-memz-deploy root@37.27.96.88

# If successful, trigger the deployment script
ssh root@37.27.96.88 "cd /opt/agent-memz && bash scripts/deploy-server.sh"
```

### Automatic Deployment

Once GitHub Actions is configured:

```bash
# Make any change to your code
echo "# Test deployment" >> README.md

# Commit and push
git add .
git commit -m "Test auto-deployment"
git push origin master

# Watch the deployment in GitHub Actions:
# https://github.com/klogins-hash/agent-memz-the-wordz-v0.1/actions
```

## Deployment Process

When you push to `master`, the following happens:

1. **GitHub Actions triggers** - Workflow starts
2. **Checkout code** - Latest code is checked out
3. **Setup SSH** - SSH key is loaded from secrets
4. **Deploy to server** - Script runs on server via SSH:
   - Pulls latest code from GitHub
   - Backs up database (if exists)
   - Updates `.env` with secrets
   - Stops old containers
   - Pulls new Docker images
   - Starts containers
   - Verifies services are healthy
5. **Verify deployment** - Checks container status
6. **Notify status** - Reports success/failure

## Monitoring Deployment

### View GitHub Actions Logs

1. Go to: https://github.com/klogins-hash/agent-memz-the-wordz-v0.1/actions
2. Click on the latest workflow run
3. View each step's logs

### Check Server Status

```bash
# SSH to server
ssh root@37.27.96.88

# Check running containers
cd /opt/agent-memz
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service
docker-compose logs postgres
docker-compose logs redis
docker-compose logs minio
```

### Access Services

Once deployed, services are available at:

- **PostgreSQL**: `37.27.96.88:5432`
- **Redis**: `37.27.96.88:6379`
- **MinIO API**: `http://37.27.96.88:9000`
- **MinIO Console**: `http://37.27.96.88:9001`

**MinIO Console Login:**
- Username: `minioadmin`
- Password: The value you set in `MINIO_ROOT_PASSWORD` secret

## Rollback

If a deployment fails, you can rollback:

```bash
# SSH to server
ssh root@37.27.96.88

cd /opt/agent-memz

# See recent commits
git log --oneline -10

# Rollback to previous commit
git reset --hard <commit-hash>

# Restart containers
docker-compose down
docker-compose up -d
```

## Database Backups

Backups are automatically created before each deployment in `/opt/agent-memz-backups/`.

### Manual Backup

```bash
# SSH to server
ssh root@37.27.96.88

# Create backup
cd /opt/agent-memz
mkdir -p /opt/agent-memz-backups/manual_$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dumpall -U agentmemz > /opt/agent-memz-backups/manual_$(date +%Y%m%d_%H%M%S)/backup.sql
```

### Restore from Backup

```bash
# SSH to server
ssh root@37.27.96.88

cd /opt/agent-memz

# Stop containers
docker-compose down

# Start only postgres
docker-compose up -d postgres

# Wait for postgres to be ready
sleep 10

# Restore backup
cat /opt/agent-memz-backups/<backup-dir>/backup.sql | docker-compose exec -T postgres psql -U agentmemz

# Restart all services
docker-compose down
docker-compose up -d
```

## Troubleshooting

### Deployment Fails

1. **Check GitHub Actions logs** for error messages
2. **Verify SSH access** from your local machine
3. **Check server logs**: `ssh root@37.27.96.88 "cd /opt/agent-memz && docker-compose logs"`

### SSH Connection Issues

```bash
# Test SSH connection
ssh -i ~/.ssh/agent-memz-deploy root@37.27.96.88 "echo 'Connection successful!'"

# If fails, check:
# 1. Public key is in server's authorized_keys
# 2. Private key is in GitHub Secrets
# 3. Server firewall allows SSH (port 22)
```

### Container Won't Start

```bash
# SSH to server
ssh root@37.27.96.88

cd /opt/agent-memz

# Check container logs
docker-compose logs <service-name>

# Check disk space
df -h

# Check Docker status
docker info

# Restart specific service
docker-compose restart <service-name>
```

### Port Conflicts

If ports are already in use on the server:

```bash
# Check what's using the port
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :9000  # MinIO

# Edit docker-compose.yml to use different ports
# Example: "5433:5432" instead of "5432:5432"
```

## Security Recommendations

1. **Change default passwords** - Update all passwords in GitHub Secrets
2. **Enable firewall** - Only allow necessary ports:
   ```bash
   ufw allow 22    # SSH
   ufw allow 5432  # PostgreSQL (if needed externally)
   ufw allow 6379  # Redis (if needed externally)
   ufw allow 9000  # MinIO API
   ufw allow 9001  # MinIO Console
   ufw enable
   ```
3. **Use non-root user** - Create a dedicated deployment user
4. **Enable SSH key only** - Disable password authentication
5. **Regular updates** - Keep server software updated
6. **Monitor logs** - Set up log aggregation and monitoring

## Manual Deployment (Without GitHub Actions)

If you need to deploy without GitHub Actions:

```bash
# From your local machine
ssh root@37.27.96.88 << 'EOF'
  cd /opt/agent-memz
  git pull origin master
  docker-compose down
  docker-compose up -d --build
  docker-compose ps
EOF
```

## Advanced Configuration

### Custom Domain Setup

To use a custom domain instead of IP:

1. Point your domain's A record to `37.27.96.88`
2. Install Nginx reverse proxy
3. Set up SSL with Let's Encrypt
4. Configure Nginx to proxy to services

### Scaling

For production load:

1. **PostgreSQL**: Use managed database or set up replication
2. **Redis**: Use Redis Cluster for high availability
3. **MinIO**: Use distributed mode with multiple nodes
4. **Application**: Run multiple instances behind load balancer

## Support

For issues:
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Review container logs: `docker-compose logs`
- Open issue on GitHub: https://github.com/klogins-hash/agent-memz-the-wordz-v0.1/issues
