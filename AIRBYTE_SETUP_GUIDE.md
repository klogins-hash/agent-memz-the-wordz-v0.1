# Airbyte Setup Guide - Getting Started with ETL

## What Airbyte Does

Airbyte is an **ETL platform** - it doesn't automatically sync data. You need to configure:
1. **Sources** - Where data comes FROM (APIs, databases, files, etc.)
2. **Destinations** - Where data goes TO (your PostgreSQL database, data warehouses, etc.)
3. **Connections** - Define which sources sync to which destinations
4. **Schedules** - How often data syncs (manual, hourly, daily, etc.)

## Current Status

✅ Airbyte is **installed and running**
❌ No data pipelines are configured yet

## How to Set Up Your First Data Pipeline

### Step 1: Access Airbyte UI

1. Go to: https://etl.basedaf.ai (or http://37.27.96.88:8500)
2. Login with password: `bHnGdFlnuODl5S3ad5nHfI4RNOO4t4qP`

### Step 2: Configure a Destination (Your PostgreSQL)

Your existing PostgreSQL database can be used as a destination:

```
Destination Type: PostgreSQL
Host: agent-memz-postgres (or 37.27.96.88)
Port: 5432
Database: agent_memory
Username: agentmemz
Password: changeme_postgres_fd3d601f2a9a801cf113edbf73f8c5ca
```

**Note:** You may want to create a separate database for ETL data instead of using `agent_memory`.

### Step 3: Configure a Source

Common sources you might want to connect:

#### Option A: REST API Source
- Any API endpoint you want to pull data from
- Configure authentication, endpoints, and data format

#### Option B: File Source
- CSV, JSON, Parquet files from S3, Google Drive, local files
- Configure file location and format

#### Option C: Database Source
- Another PostgreSQL, MySQL, MongoDB, etc.
- Full database replication or specific tables

#### Option D: SaaS Applications
Airbyte has 300+ pre-built connectors:
- Google Sheets
- Airtable
- Stripe
- Shopify
- Salesforce
- GitHub
- And many more...

### Step 4: Create a Connection

1. Select your **Source**
2. Select your **Destination** (your PostgreSQL)
3. Configure:
   - **Sync Mode**: Full Refresh or Incremental
   - **Schedule**: Manual, hourly, daily, custom cron
   - **Namespace**: Which database/schema to use
   - **Stream Selection**: Which tables/data to sync

### Step 5: Run Your First Sync

1. Click "Sync Now" or wait for scheduled sync
2. Monitor progress in the UI
3. Check your PostgreSQL database for the new data

## Example Use Cases

### Use Case 1: API to Database
```
Source: REST API (customer data from external service)
   ↓
Destination: PostgreSQL (agent_memory database)
Schedule: Every 1 hour
```

### Use Case 2: Multi-Source Analytics
```
Source 1: Google Sheets (sales data)
Source 2: Stripe API (payment data)
Source 3: GitHub API (development activity)
   ↓
Destination: PostgreSQL (analytics_db)
Schedule: Daily at 2 AM
```

### Use Case 3: Database Replication
```
Source: Production PostgreSQL (read replica)
   ↓
Destination: Analytics PostgreSQL (your server)
Schedule: Every 15 minutes
```

## Connecting to Your Existing PostgreSQL

### Option 1: Same Database (Not Recommended)
- Use existing `agent_memory` database
- Risk: ETL data mixed with application data

### Option 2: New Database (Recommended)
```bash
# Create new database for ETL data
ssh root@37.27.96.88
docker exec -it agent-memz-postgres psql -U agentmemz -d postgres
CREATE DATABASE airbyte_data;
GRANT ALL PRIVILEGES ON DATABASE airbyte_data TO agentmemz;
\q
```

Then configure Airbyte destination:
```
Database: airbyte_data
Username: agentmemz
Password: changeme_postgres_fd3d601f2a9a801cf113edbf73f8c5ca
```

## Does Airbyte Store Data?

**No!** Airbyte is just the **pipeline**:
- It reads data from sources
- Transforms it if needed
- Writes it to destinations
- Airbyte itself doesn't store your data (only metadata about syncs)

## Monitoring ETL Jobs

### Via Airbyte UI
1. Go to **Connections** tab
2. View sync history, logs, and metrics
3. See failed syncs and errors

### Via Logs
```bash
ssh root@37.27.96.88
cd /root/airbyte
abctl local logs
```

## Common Workflows

### Workflow 1: Customer Data Sync
```
1. Configure Salesforce as Source
2. Configure PostgreSQL (airbyte_data) as Destination
3. Select tables: accounts, contacts, opportunities
4. Set schedule: Every 6 hours
5. Enable → Data automatically syncs every 6 hours
```

### Workflow 2: Analytics Dashboard
```
1. Multiple sources: Google Analytics, Stripe, PostgreSQL
2. Single destination: Data warehouse (PostgreSQL)
3. Transform data in destination using dbt
4. Visualize in Grafana
```

## What You Need to Do Next

Airbyte is **installed but not configured**. To actually use it:

1. **Access the UI**: https://etl.basedaf.ai
2. **Decide what data you want to sync**
3. **Configure sources** (where data comes from)
4. **Configure destinations** (your PostgreSQL or other destinations)
5. **Create connections** (source → destination mappings)
6. **Set schedules** (how often to sync)
7. **Monitor** sync jobs in the UI

## Security Considerations

- Airbyte stores connection credentials (encrypted)
- Use separate database user for ETL with limited permissions
- Consider network security (firewall rules, VPN)
- Regularly rotate credentials
- Monitor sync logs for suspicious activity

## Resources

- **Airbyte Docs**: https://docs.airbyte.com
- **Connector Catalog**: https://docs.airbyte.com/integrations/
- **Source Setup Guides**: https://docs.airbyte.com/integrations/sources/
- **Destination Setup Guides**: https://docs.airbyte.com/integrations/destinations/

## Need Help?

If you want me to help configure specific sources or destinations, let me know:
- What data do you want to sync?
- Where is it coming from?
- What's the use case?
