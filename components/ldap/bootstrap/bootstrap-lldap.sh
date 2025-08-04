#!/bin/bash
# LLDAP Bootstrap script for Redstone project
# Using the official LLDAP bootstrap approach - https://github.com/lldap/lldap/blob/main/example_configs/bootstrap/bootstrap.md

set -e

echo "🔐 LLDAP Bootstrap for Redstone"

# Default password if not set
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminadmin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Emojis for better UX
SUCCESS="✅"
FAILURE="❌"
INFO="ℹ️"

# First, check if the LDAP container is running
LDAP_CONTAINER=$(docker ps --filter name=ldap --format "{{.Names}}" | grep -E 'ldap|lldap' | head -n 1)

if [ -z "$LDAP_CONTAINER" ]; then
  echo "$FAILURE LDAP container not found. Please start the LDAP service first."
  exit 1
fi

echo "$INFO Using LDAP container: $LDAP_CONTAINER"

# Set up the environment variables for bootstrap
echo "$INFO Setting up bootstrap environment..."

# Get the docker port mapping for LLDAP API access
LLDAP_PORT=$(docker port "$LDAP_CONTAINER" 17170 | cut -d ':' -f 2 | head -n 1)

if [ -z "$LLDAP_PORT" ]; then
  LLDAP_PORT="17170" # Default port if not mapped
fi

LLDAP_API_URL="http://localhost:$LLDAP_PORT"
echo "$INFO LLDAP API URL: $LLDAP_API_URL"

# Copy bootstrap files to container
echo "$INFO Copying bootstrap files to container..."

# Create temporary directory in container
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap

# Copy bootstrap files 
docker cp "$SCRIPT_DIR/user-configs" "$LDAP_CONTAINER:/tmp/bootstrap/"
docker cp "$SCRIPT_DIR/group-configs" "$LDAP_CONTAINER:/tmp/bootstrap/"

# Check if official bootstrap script exists in container
if ! docker exec "$LDAP_CONTAINER" test -f /app/bootstrap.sh; then
  echo "$INFO Official bootstrap script not found in container, downloading locally..."
  
  # Download script locally and then copy to container
  curl -s -o /tmp/bootstrap.sh https://raw.githubusercontent.com/lldap/lldap/main/scripts/bootstrap.sh
  
  # Copy the script to the container
  docker cp /tmp/bootstrap.sh "$LDAP_CONTAINER:/tmp/bootstrap/bootstrap.sh"
  docker exec "$LDAP_CONTAINER" chmod +x /tmp/bootstrap/bootstrap.sh
  BOOTSTRAP_PATH="/tmp/bootstrap/bootstrap.sh"
  
  # Clean up local file
  rm /tmp/bootstrap.sh
else
  BOOTSTRAP_PATH="/app/bootstrap.sh"
  echo "$INFO Using official bootstrap script from container: $BOOTSTRAP_PATH"
fi

# Execute bootstrap script inside the container
echo "$INFO Running bootstrap script in container..."
docker exec -e LLDAP_URL="http://localhost:17170" \
  -e LLDAP_ADMIN_USERNAME="admin" \
  -e LLDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD" \
  -e USER_CONFIGS_DIR="/tmp/bootstrap/user-configs" \
  -e GROUP_CONFIGS_DIR="/tmp/bootstrap/group-configs" \
  -e DO_CLEANUP="false" \
  "$LDAP_CONTAINER" \
  $BOOTSTRAP_PATH

# Check the exit status of the bootstrap script
if [ $? -eq 0 ]; then
  echo "$SUCCESS LLDAP bootstrap completed successfully!"
else
  echo "$FAILURE LLDAP bootstrap failed."
  exit 1
fi
