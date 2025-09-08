#!/bin/bash
# Generate LDAP configuration from template using environment variables
# This script creates the final ldap.toml file from the template

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/auth/ldap.toml.template"
OUTPUT_FILE="${SCRIPT_DIR}/auth/ldap.toml"

# Default values for missing environment variables
export LDAP_HOST="${LDAP_HOST:-ldap}"
export LDAP_PORT="${LDAP_PORT:-3890}"
export LDAP_USE_SSL="${LDAP_USE_SSL:-false}"
export LDAP_START_TLS="${LDAP_START_TLS:-false}"
export LDAP_SKIP_SSL_VERIFY="${LDAP_SKIP_SSL_VERIFY:-true}"
export LDAP_BIND_DN="${LDAP_BIND_DN:-uid=admin,ou=people,dc=redstone,dc=local}"
export LDAP_BIND_PASSWORD="${LDAP_BIND_PASSWORD:-adminadmin}"
export LDAP_SEARCH_FILTER="${LDAP_SEARCH_FILTER:-(uid=%s)}"
export LDAP_SEARCH_BASE_DNS="${LDAP_SEARCH_BASE_DNS:-ou=people,dc=redstone,dc=local}"
export LDAP_BASE_DN="${LDAP_BASE_DN:-dc=redstone,dc=local}"

echo "Generating LDAP configuration from template..."
echo "Template: $TEMPLATE_FILE"
echo "Output: $OUTPUT_FILE"

# Use envsubst to replace environment variables in template
if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    echo "✓ LDAP configuration generated successfully"
else
    echo "Error: envsubst not found. Please install gettext package."
    exit 1
fi

# Validate the generated file
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "✓ Generated LDAP config file: $OUTPUT_FILE"
    echo "Configuration preview:"
    head -20 "$OUTPUT_FILE"
else
    echo "✗ Failed to generate LDAP configuration"
    exit 1
fi
