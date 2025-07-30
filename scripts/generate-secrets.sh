#!/bin/bash
set -e

echo "🔑 Generating secrets for .env file..."

# Function to generate a random string
generate_random_string() {
  local length=$1
  cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# Check if .env file exists
if [ ! -f ".env" ]; then
  echo "❌ Error: .env file not found"
  exit 1
fi

# Generate PostgreSQL password if not already set
if ! grep -q "^POSTGRES_PASSWORD=" .env || grep -q "^POSTGRES_PASSWORD=$" .env; then
  echo "Generating PostgreSQL password..."
  sed -i '' "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(generate_random_string 16)/" .env
fi

# Generate Redis password if not already set
if ! grep -q "^REDIS_PASSWORD=" .env || grep -q "^REDIS_PASSWORD=$" .env; then
  echo "Generating Redis password..."
  sed -i '' "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$(generate_random_string 16)/" .env
fi

# Generate LDAP admin password if not already set
if ! grep -q "^LDAP_ADMIN_PASSWORD=" .env || grep -q "^LDAP_ADMIN_PASSWORD=$" .env; then
  echo "Generating LDAP admin password..."
  sed -i '' "s/^LDAP_ADMIN_PASSWORD=.*/LDAP_ADMIN_PASSWORD=$(generate_random_string 16)/" .env
fi

# Generate other secrets as needed

echo "✅ Secrets generated successfully"
