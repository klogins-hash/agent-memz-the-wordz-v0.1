# Airbyte ETL - Multitenancy Setup Guide

## Overview

Airbyte has been deployed at **https://etl.basedaf.ai** with native multitenancy support using workspaces.

## Architecture

- **Web UI**: https://etl.basedaf.ai
- **API**: https://etl.basedaf.ai/api/v1/
- **Database**: Shared PostgreSQL instance (database: `airbyte`)
- **Version**: 0.50.33
- **Network**: Integrated with Coolify's Traefik reverse proxy

## Deployed Services

1. **airbyte-server** - API and scheduler
2. **airbyte-webapp** - Web interface
3. **airbyte-worker** - Runs data sync jobs
4. **airbyte-temporal** - Workflow orchestration

## Default Credentials

**⚠️ IMPORTANT: Change these immediately after first login**

- Email: `airbyte@example.com`
- Password: `password`

## Multitenancy with Workspaces

Airbyte provides native multitenancy through **Workspaces**. Each tenant gets their own isolated workspace with:

- Separate sources and destinations
- Independent sync configurations
- Isolated sync history and logs
- Workspace-specific API keys
- Individual user access controls

### Creating Workspaces for Tenants

1. **Access Airbyte**
   ```
   https://etl.basedaf.ai
   ```

2. **Admin Setup** (First Time)
   - Log in with default credentials
   - Go to Settings → Account → Change Password
   - Update admin email if needed

3. **Create Workspace for Each Tenant**
   - Click on workspace dropdown (top left)
   - Click "+ New Workspace"
   - Enter workspace name (e.g., "Tenant-CompanyName")
   - Add workspace description
   - Click "Create Workspace"

4. **Configure Workspace Permissions**
   - Go to Settings → Access Management
   - Invite users to specific workspaces
   - Assign roles (Admin, Editor, Viewer)

### Workspace Isolation

Each workspace maintains complete data isolation:

```
Workspace: Tenant A
├── Sources (databases, APIs, files)
├── Destinations (data warehouses, databases)
├── Connections (sync configurations)
├── Sync History
└── API Keys

Workspace: Tenant B
├── Sources (completely separate)
├── Destinations (completely separate)
├── Connections
├── Sync History
└── API Keys
```

## Common ETL Patterns

### Pattern 1: Database Replication
Source: PostgreSQL → Destination: BigQuery/Snowflake/Redshift
- Use for: Analytics, reporting, data warehousing

### Pattern 2: API to Database
Source: REST API → Destination: PostgreSQL/MySQL
- Use for: Third-party data ingestion

### Pattern 3: File-based ETL
Source: S3/GCS → Destination: Database
- Use for: Batch file processing

## API Access (Per Workspace)

Each workspace can generate API keys for programmatic access:

```bash
# Example: Trigger a sync via API
curl -X POST https://etl.basedaf.ai/api/v1/connections/sync \
  -H "Authorization: Bearer <workspace-api-key>" \
  -H "Content-Type: application/json" \
  -d '{"connectionId": "<connection-id>"}'
```

## Monitoring & Logs

### View Logs
```bash
# All Airbyte services
ssh root@37.27.96.88
cd /root/agent-memz-the-wordz-v0.1
docker compose -f docker-compose.airbyte.yml logs -f

# Specific service
docker logs agent-memz-airbyte-server -f
docker logs agent-memz-airbyte-worker -f
```

### Check Service Status
```bash
docker compose -f docker-compose.airbyte.yml ps
```

## Scaling Considerations

### Worker Scaling
For high-volume sync operations, you can scale the worker:

```yaml
# In docker-compose.airbyte.yml
airbyte-worker:
  deploy:
    replicas: 3  # Add multiple workers
```

### Database Connection Pooling
The shared PostgreSQL instance is configured with:
- Connection pooling enabled
- Max connections: 100 (default)
- Connections per workspace: Dynamically allocated

## Backup & Recovery

### Database Backup
```bash
# Backup Airbyte configuration database
docker exec agent-memz-postgres pg_dump -U agentmemz airbyte > airbyte_backup.sql

# Restore
docker exec -i agent-memz-postgres psql -U agentmemz airbyte < airbyte_backup.sql
```

### Workspace Export
Each workspace can export its configuration:
- Settings → Workspace → Export Configuration
- Saves all sources, destinations, and connections as JSON

## Security Best Practices

1. **Change Default Credentials** immediately
2. **Use Workspace API Keys** instead of sharing admin credentials
3. **Enable HTTPS** (already configured via Traefik)
4. **Regular Backups** of configuration database
5. **Audit User Access** per workspace quarterly
6. **Rotate API Keys** every 90 days

## Troubleshooting

### Services Not Starting
```bash
# Check logs for errors
docker logs agent-memz-airbyte-server --tail 100

# Restart services
cd /root/agent-memz-the-wordz-v0.1
docker compose -f docker-compose.airbyte.yml restart
```

### Database Connection Issues
```bash
# Verify PostgreSQL is accessible
docker exec agent-memz-postgres pg_isready -U agentmemz

# Check Airbyte database
docker exec agent-memz-postgres psql -U agentmemz -d airbyte -c "\dt"
```

### Temporal Issues
```bash
# Temporal service logs
docker logs agent-memz-airbyte-temporal -f

# Restart temporal
docker restart agent-memz-airbyte-temporal
```

## Upgrade Process

```bash
# 1. Backup database
docker exec agent-memz-postgres pg_dump -U agentmemz airbyte > airbyte_backup_$(date +%Y%m%d).sql

# 2. Update version in docker-compose.airbyte.yml
# Change: airbyte/server:0.50.33 to new version

# 3. Pull new images
docker compose -f docker-compose.airbyte.yml pull

# 4. Restart services
docker compose -f docker-compose.airbyte.yml up -d

# 5. Verify
docker compose -f docker-compose.airbyte.yml ps
```

## Resources

- **Airbyte Documentation**: https://docs.airbyte.com
- **API Reference**: https://docs.airbyte.com/api-documentation
- **Connector Catalog**: https://docs.airbyte.com/integrations
- **Community Slack**: https://airbyte.com/community

## Support

For issues or questions:
1. Check logs first: `docker compose -f docker-compose.airbyte.yml logs`
2. Consult Airbyte documentation
3. Visit Airbyte Community Slack
4. Check GitHub issues: https://github.com/airbytehq/airbyte

---

**Deployed**: November 2025
**URL**: https://etl.basedaf.ai
**Version**: Airbyte 0.50.33
**Backend**: PostgreSQL 15 with pgvector
