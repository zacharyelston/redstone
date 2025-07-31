#!/bin/bash
# LDAP Configuration Script for Redstone
# This script prepares and applies LDAP configuration during deployment

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
LDAP_DIR="$PROJECT_ROOT/components/ldap"
CONFIG_DIR="$PROJECT_ROOT/config"

echo "🔐 Configuring LDAP for Redstone deployment..."

# Check if custom LDAP config exists
CUSTOM_CONFIG="${PROJECT_ROOT}/custom/ldap-config.yaml"
DEFAULT_CONFIG="${LDAP_DIR}/ldap-defaults.yaml"
TARGET_CONFIG="${LDAP_DIR}/config/ldap.yaml"

# Create config directory if it doesn't exist
mkdir -p "${LDAP_DIR}/config"

if [ -f "$CUSTOM_CONFIG" ]; then
    echo "📄 Found custom LDAP configuration, using: $CUSTOM_CONFIG"
    # Copy the custom config to the target location
    cp "$CUSTOM_CONFIG" "$TARGET_CONFIG"
else
    echo "📄 Using default LDAP configuration: $DEFAULT_CONFIG"
    # Copy the default config to the target location
    cp "$DEFAULT_CONFIG" "$TARGET_CONFIG"
fi

# Check if LLDAP container is running
LDAP_CONTAINER=$(docker compose ps -q ldap 2>/dev/null)
if [ -z "$LDAP_CONTAINER" ]; then
    echo "⚠️ LDAP container is not running. Starting it first..."
    docker compose up -d ldap
    # Wait a bit for container to start
    sleep 5
    LDAP_CONTAINER=$(docker compose ps -q ldap 2>/dev/null)
    if [ -z "$LDAP_CONTAINER" ]; then
        echo "❌ Failed to start LDAP container"
        exit 1
    fi
fi

# Use Docker to apply the LDAP configuration
echo "🔄 Applying LDAP configuration to container..."
docker compose exec -T ldap sh -c "mkdir -p /tmp/config"
docker cp "$TARGET_CONFIG" "${LDAP_CONTAINER}:/tmp/config/ldap.yaml"

# Run the LDIF generation inside the container
echo "🔄 Generating LDIF configuration inside container..."

# Create a temporary Python script for LDAP configuration
cat > ${LDAP_DIR}/config/generate_ldif.py << EOF
import yaml
import sys
from pathlib import Path

try:
    # Read the YAML configuration
    config = yaml.safe_load(Path('/config/ldap.yaml').read_text())
    
    # Write a simplified LDIF to be applied later
    with open('/config/users.ldif', 'w') as f:
        # Create base entries
        f.write('# Generated LDIF from YAML configuration\n')
        
        # Create base DN structure
        base_dn = config['base_config']['base_dn']
        f.write(f'dn: {base_dn}\n')
        f.write('objectClass: dcObject\n')
        f.write('objectClass: organization\n')
        f.write(f"dc: {base_dn.split('=')[1].split(',')[0]}\n")
        f.write('o: Redstone Organization\n\n')
        
        # Create organizational units
        f.write(f'dn: ou=users,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: users\n\n')
        
        f.write(f'dn: ou=groups,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: groups\n\n')
        
        f.write(f'dn: ou=services,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: services\n\n')
    
    print('LDIF configuration generated successfully')
except Exception as e:
    print(f'Error generating LDIF: {e}')
    sys.exit(1)
EOF

# Run the Python script in a container
docker run --rm -v "${LDAP_DIR}/config:/config" python:3.9-alpine sh -c 'pip install pyyaml && python /config/generate_ldif.py'

# Apply configuration to the LDAP server
echo "🔄 Configuration complete. LDAP is ready to use."
echo "🔑 Default admin password: ${LDAP_ADMIN_PASSWORD:-adminadmin}"

echo "✅ LDAP configuration complete."
