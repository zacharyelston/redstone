#!/bin/bash
set -e

# Create the Redmica user and grant privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
-- Create role if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'redmica') THEN
    CREATE ROLE redmica WITH LOGIN PASSWORD 'redmica' CREATEDB;
  END IF;
END
$$;

-- Grant privileges on existing database
GRANT ALL PRIVILEGES ON DATABASE redmica_production TO redmica;
EOSQL

# Initialize schema if needed
# This is a placeholder - Redmica will handle its own schema migration
