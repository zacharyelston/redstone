#!/bin/bash
set -e

echo "💾 Initializing database schemas and permissions..."

# Function to execute SQL in PostgreSQL container
exec_sql() {
  docker exec redstone-postgres-1 psql -U postgres -c "$1"
}

echo "Checking for redmica schema..."
# Create redmica schema if not exists
exec_sql "CREATE SCHEMA IF NOT EXISTS redmica;"

echo "Creating redmica_service role if not exists..."
# Use a simpler approach to create the role if it doesn't exist
ROLE_EXISTS=$(docker exec redstone-postgres-1 psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='redmica_service'")
if [ -z "$ROLE_EXISTS" ]; then
  exec_sql "CREATE ROLE redmica_service WITH LOGIN PASSWORD '${POSTGRES_PASSWORD:-postgres}';"
  echo "Role redmica_service created"
else
  echo "Role redmica_service already exists"
fi

echo "Granting permissions on redmica schema..."
# Grant permissions on redmica schema
exec_sql "GRANT ALL PRIVILEGES ON SCHEMA redmica TO redmica_service;"
exec_sql "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA redmica TO redmica_service;"
exec_sql "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA redmica TO redmica_service;"
exec_sql "ALTER DEFAULT PRIVILEGES IN SCHEMA redmica GRANT ALL PRIVILEGES ON TABLES TO redmica_service;"
exec_sql "ALTER DEFAULT PRIVILEGES IN SCHEMA redmica GRANT ALL PRIVILEGES ON SEQUENCES TO redmica_service;"

echo "Granting permissions on public schema..."
# Grant permissions on public schema
exec_sql "GRANT ALL PRIVILEGES ON SCHEMA public TO redmica_service;"
exec_sql "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO redmica_service;"
exec_sql "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO redmica_service;"
exec_sql "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO redmica_service;"
exec_sql "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO redmica_service;"

# Set search path for redmica_service
exec_sql "ALTER ROLE redmica_service SET search_path TO redmica, public;"

echo "✅ Database initialization complete"
