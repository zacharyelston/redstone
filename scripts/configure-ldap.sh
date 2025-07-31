#!/bin/bash
# LDAP Configuration Script for Redstone
# This script prepares and applies LDAP configuration during deployment

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
LDAP_DIR="$PROJECT_ROOT/components/ldap"

echo "🔐 Configuring LDAP for Redstone deployment..."

# Check if custom LDAP config exists
CUSTOM_CONFIG="${PROJECT_ROOT}/custom/ldap-config.yaml"
DEFAULT_CONFIG="${LDAP_DIR}/ldap-defaults.yaml"
TARGET_CONFIG="${LDAP_DIR}/ldap-defaults.yaml"

if [ -f "$CUSTOM_CONFIG" ]; then
    echo "📄 Found custom LDAP configuration, using: $CUSTOM_CONFIG"
    # Copy the custom config to the default location
    cp "$CUSTOM_CONFIG" "$TARGET_CONFIG"
else
    echo "📄 Using default LDAP configuration: $DEFAULT_CONFIG"
fi

# Run the LDAP initialization script
cd "$LDAP_DIR"
./initialize-ldap.sh

echo "✅ LDAP configuration complete."
