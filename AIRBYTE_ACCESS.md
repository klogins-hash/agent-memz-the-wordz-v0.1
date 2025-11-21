# Airbyte Access Guide

## Deployment Status

Airbyte is successfully installed via `abctl` (official Airbyte CLI tool) on port **8500**.

### Credentials
- **Email:** [not set] (use any email)
- **Password:** `bHnGdFlnuODl5S3ad5nHfI4RNOO4t4qP`
- **Client-Id:** `51a6756e-5a27-4dc1-a876-73efb1509e21`
- **Client-Secret:** `p3CEXmS2Li7rudpNHf4UH97uN7FRVe4C`

## Access Methods

### Direct Access
```
http://37.27.96.88:8500
```

### Via HTTPS (After Traefik Configuration)
```
https://etl.basedaf.ai
```

## Next Steps After Installation

### 1. Verify Installation
```bash
ssh root@37.27.96.88
cd /root/airbyte
abctl local status
```

### 2. Get Credentials
```bash
abctl local credentials
```

Current credentials (generated on installation):
- Email: [not set]
- Password: `bHnGdFlnuODl5S3ad5nHfI4RNOO4t4qP`
- Client-Id: `51a6756e-5a27-4dc1-a876-73efb1509e21`
- Client-Secret: `p3CEXmS2Li7rudpNHf4UH97uN7FRVe4C`

### 3. Configure Traefik Routing

Add to Coolify/Traefik to route `https://etl.basedaf.ai` → `http://localhost:8500`

Or manually add Traefik labels to the Airbyte containers.

## Managing Airbyte

### Check Status
```bash
ssh root@37.27.96.88
cd /root/airbyte
abctl local status
```

### View Logs
```bash
abctl local logs
```

### Stop Airbyte
```bash
abctl local uninstall
```

### Restart Airbyte
```bash
abctl local install --port 8500
```

## Default Workspace

Airbyte will create a default workspace automatically. You can create additional workspaces later from the UI for multitenancy.

## Data Location

All Airbyte data is stored in:
- `/root/.airbyte/abctl/` - Configuration
- Kubernetes volumes managed by Kind cluster

## Backup

To backup Airbyte configuration:
```bash
# Export workspace configuration from UI
# Settings → Workspace → Export Configuration
```

## Support

- Official Docs: https://docs.airbyte.com
- abctl Docs: https://docs.airbyte.com/using-airbyte/getting-started/oss-quickstart
