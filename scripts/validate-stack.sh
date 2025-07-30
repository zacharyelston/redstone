#!/bin/bash
set -e

echo "🛠️ Validating Docker Compose stack configuration..."

# Validate the docker-compose.yml file
echo "\nChecking docker-compose.yml syntax:"
if docker compose config > /dev/null; then
  echo "✅ Docker Compose configuration is valid"
else
  echo "❌ Docker Compose configuration is invalid"
  exit 1
fi

# Check for required services
required_services=("postgres" "redmica" "ldap" "redis")

echo "\nChecking for required services:"
for service in "${required_services[@]}"; do
  if grep -q "^  $service:" docker-compose.yml; then
    echo "✅ Service $service is defined"
  else
    echo "❌ Service $service is missing from docker-compose.yml"
    exit 1
  fi
done

# Check dependency order
echo "\nChecking service dependencies:"

# Check if redmica depends on postgres
if grep -A20 "^  redmica:" docker-compose.yml | grep -q "depends_on"; then
  if grep -A20 "^  redmica:" docker-compose.yml | grep -A5 "depends_on" | grep -q "postgres"; then
    echo "✅ Redmica depends on postgres"
  else
    echo "⚠️ Warning: Redmica service may start before postgres"
  fi
else
  echo "⚠️ Warning: Redmica service may start before postgres"
fi

# Check if postgres depends on ldap
if grep -A20 "^  postgres:" docker-compose.yml | grep -q "depends_on"; then
  if grep -A20 "^  postgres:" docker-compose.yml | grep -A5 "depends_on" | grep -q "ldap"; then
    echo "✅ Postgres depends on ldap"
  else
    echo "⚠️ Warning: Postgres service may start before ldap"
  fi
else
  echo "⚠️ Warning: Postgres service may start before ldap"
fi

# Check for Docker networks
if grep -q "networks:" docker-compose.yml; then
  echo "✅ Networks are defined"
else
  echo "⚠️ Warning: No networks defined in docker-compose.yml"
fi

# Check for Docker volumes
if grep -q "volumes:" docker-compose.yml; then
  echo "✅ Volumes are defined"
else
  echo "⚠️ Warning: No volumes defined in docker-compose.yml"
fi

echo "\n✅ Stack validation complete"
