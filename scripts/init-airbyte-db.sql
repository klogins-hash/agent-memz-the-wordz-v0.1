-- Airbyte Database Initialization
-- This script creates the Airbyte database and required extensions

-- Create the Airbyte database if it doesn't exist
SELECT 'CREATE DATABASE airbyte'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airbyte')\gexec

-- Connect to the airbyte database
\c airbyte

-- Create required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Grant necessary privileges
GRANT ALL PRIVILEGES ON DATABASE airbyte TO agentmemz;

-- Create schema for Airbyte
CREATE SCHEMA IF NOT EXISTS airbyte AUTHORIZATION agentmemz;

GRANT ALL ON SCHEMA airbyte TO agentmemz;
GRANT ALL ON SCHEMA public TO agentmemz;

-- Grant default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA airbyte GRANT ALL ON TABLES TO agentmemz;
ALTER DEFAULT PRIVILEGES IN SCHEMA airbyte GRANT ALL ON SEQUENCES TO agentmemz;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO agentmemz;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO agentmemz;

-- Note: Airbyte will create its own tables on first startup
