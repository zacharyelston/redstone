#!/bin/bash
set -e

echo "📜 Validating environment configuration..."

# Load environment variables from .env file
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
else
  echo "❌ Error: .env file not found"
  exit 1
fi

# Check for required variables
required_vars=(
  "POSTGRES_PASSWORD"
  "REDIS_PASSWORD"
  "LDAP_ADMIN_PASSWORD"
)

# Optional variables with defaults
optional_vars=(
  "POSTGRES_USER=postgres"
  "POSTGRES_DB=redmica"
  "REDMICA_PORT=3000"
  "GRAFANA_PORT=3001"
)

# Check required variables
errors=0
echo "Checking required variables:"
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ $var is not set"
    errors=$((errors+1))
  else
    echo "✅ $var is set"
  fi
done

# Check optional variables and set defaults if needed
echo "\nChecking optional variables:"
for pair in "${optional_vars[@]}"; do
  var=${pair%%=*}
  default=${pair#*=}
  
  if [ -z "${!var}" ]; then
    echo "⚠️ $var is not set, using default: $default"
    export $var="$default"
  else
    echo "✅ $var is set to ${!var}"
  fi
done

# Check for service-specific configurations
echo "\nChecking service configurations:"

# LDAP configuration
if [ -z "$LDAP_ADMIN_DN" ]; then
  echo "⚠️ LDAP_ADMIN_DN is not set, using default: cn=admin,dc=redstone,dc=io"
  export LDAP_ADMIN_DN="cn=admin,dc=redstone,dc=io"
else
  echo "✅ LDAP_ADMIN_DN is set"
fi

# Exit with error if any required variables are missing
if [ $errors -gt 0 ]; then
  echo "\n❌ Configuration validation failed with $errors errors"
  exit 1
else
  echo "\n✅ Configuration validation passed successfully"
fi
