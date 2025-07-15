#!/bin/bash
set -e

# Redstone deployment script
# This script deploys the Redstone components using Docker Compose

# Make script executable
chmod +x ./components/postgres/config/init-redmica-db.sh

# Display header
echo "============================================"
echo "Redstone Project - Deployment Script"
echo "============================================"
echo ""

# Check if .env file exists, if not, copy from example
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please edit .env file with your configuration"
  else
    echo "No .env.example file found. Creating minimal .env file..."
    cat > .env << EOF
# Redstone Environment Configuration
POSTGRES_VERSION=15
POSTGRES_PASSWORD=postgres
REDMICA_VERSION=3.1.7
REDMICA_PORT=3000
REDMICA_SECRET_KEY_BASE=changemeinproduction
LDAP_VERSION=1.5.0
LDAP_ORGANISATION="Redstone Project"
LDAP_DOMAIN=redstone.local
LDAP_ADMIN_PASSWORD=adminpassword
LDAP_PORT=389
LDAPS_PORT=636
GRAFANA_VERSION=9.5.2
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_PORT=3001
PROMETHEUS_VERSION=v2.44.0
PROMETHEUS_PORT=9090
EOF
    echo "Created default .env file"
  fi
  echo "Please review the .env file before continuing"
  echo ""
  sleep 2
fi

# Create necessary directories
echo "Creating component directories if needed..."
mkdir -p ./components/redmica/config
mkdir -p ./components/postgres/config
mkdir -p ./components/ldap/bootstrap
mkdir -p ./components/monitoring/grafana
mkdir -p ./components/monitoring/prometheus

# Create storage directories for persistence
echo "Creating storage directories for data persistence..."
mkdir -p ./storage/postgres
mkdir -p ./storage/redmica/files
mkdir -p ./storage/redmica/plugins
mkdir -p ./storage/ldap/data
mkdir -p ./storage/ldap/config
mkdir -p ./storage/grafana
mkdir -p ./storage/prometheus

# Set appropriate permissions for storage directories
echo "Setting appropriate permissions on storage directories..."
chmod -R 777 ./storage/postgres  # PostgreSQL needs write permissions
chmod -R 777 ./storage/redmica   # Redmica needs write permissions
chmod -R 777 ./storage/ldap      # LDAP needs write permissions
chmod -R 777 ./storage/grafana   # Grafana needs write permissions
chmod -R 777 ./storage/prometheus # Prometheus needs write permissions

# Down any existing containers
echo "Stopping any existing containers..."
docker compose down --volumes --remove-orphans

# Pull latest images
echo "Pulling latest Docker images..."
docker compose pull

# Start services
echo "Starting Redstone services..."
docker compose up -d

echo ""
echo "============================================"
echo "Deployment complete!"
echo "============================================"
echo ""
echo "Redmica:     http://localhost:${REDMICA_PORT:-3000}"
echo "Grafana:     http://localhost:${GRAFANA_PORT:-3001}"
echo "Prometheus:  http://localhost:${PROMETHEUS_PORT:-9090}"
echo ""
echo "Default credentials:"
echo "- Redmica:   admin/admin"
echo "- Grafana:   admin/${GRAFANA_ADMIN_PASSWORD:-admin}"
echo ""
echo "Use 'docker compose logs -f' to view logs"
echo "Use 'docker compose down' to stop all services"
