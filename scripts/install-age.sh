#!/bin/bash
# Install Apache AGE extension for PostgreSQL
# Apache AGE provides graph database capabilities alongside relational data

set -e

echo "Installing Apache AGE extension..."

# Install build dependencies
apt-get update
apt-get install -y \
    build-essential \
    libreadline-dev \
    zlib1g-dev \
    flex \
    bison \
    git \
    postgresql-server-dev-all

# Clone Apache AGE repository
cd /tmp
if [ ! -d "age" ]; then
    git clone https://github.com/apache/age.git
fi

cd age
git checkout release/PG15/1.5.0

# Build and install AGE
make install

# Load AGE extension in the database
psql -U ${POSTGRES_USER:-agentmemz} -d ${POSTGRES_DB:-agent_memory} <<-EOSQL
    -- Load AGE extension
    CREATE EXTENSION IF NOT EXISTS age;

    -- Load AGE into the current session
    LOAD 'age';
    SET search_path = ag_catalog, "$user", public;

    -- Create a graph for memory relationships
    SELECT create_graph('memory_graph');

    -- Create a graph for conversation flows
    SELECT create_graph('conversation_graph');

    -- Notification
    DO \$\$
    BEGIN
        RAISE NOTICE 'Apache AGE extension installed successfully!';
        RAISE NOTICE 'Created graphs: memory_graph, conversation_graph';
    END \$\$;
EOSQL

echo "Apache AGE installation completed!"
echo "Available graphs: memory_graph, conversation_graph"
