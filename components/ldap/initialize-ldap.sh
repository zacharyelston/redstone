#!/bin/bash
# Initialize LDAP with default configuration
# This script generates the LDIF file from the YAML config and waits
# for the LDAP service to be available before applying the configuration

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

echo "🔐 Initializing LDAP configuration..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed. Please install Python 3."
    exit 1
fi

# Check for required Python packages
REQUIRED_PACKAGES=("pyyaml")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python3 -c "import $package" &> /dev/null; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "📦 Installing required Python packages: ${MISSING_PACKAGES[*]}"
    pip3 install --user "${MISSING_PACKAGES[@]}"
fi

# Generate LDIF from YAML config
echo "🔄 Generating LDAP configuration from defaults..."
LDAP_CONFIG_FILE="ldap-defaults.yaml"
LDIF_OUTPUT="config/users.ldif"

# Check if we should use environment variables for passwords
USE_ENV_FLAG=""
if [ "$USE_ENV_PASSWORDS" = "true" ]; then
    USE_ENV_FLAG="--env"
fi

# Generate the LDIF file
python3 generate_ldap_config.py --input "$LDAP_CONFIG_FILE" --output "$LDIF_OUTPUT" $USE_ENV_FLAG

# Check if the file was created
if [ ! -f "$LDIF_OUTPUT" ]; then
    echo "❌ Failed to generate LDIF file."
    exit 1
fi

echo "✅ LDIF configuration generated: $LDIF_OUTPUT"

# Wait for LDAP to be available
echo "⏳ Waiting for LDAP service to be ready..."
MAX_RETRIES=30
RETRY_INTERVAL=5
RETRY_COUNT=0

# Get LDAP host and port from environment or use defaults
LDAP_HOST=${LDAP_HOST:-ldap}
LDAP_PORT=${LDAP_PORT:-3890}

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if nc -z ${LDAP_HOST} ${LDAP_PORT} &> /dev/null; then
        echo "✅ LDAP service is available!"
        break
    else
        echo "⏳ LDAP service not ready yet, waiting... ($((RETRY_COUNT + 1))/$MAX_RETRIES)"
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep $RETRY_INTERVAL
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Timed out waiting for LDAP service."
    exit 1
fi

# Load the base configuration from the YAML file
DOMAIN=$(python3 -c "import yaml; print(yaml.safe_load(open('$LDAP_CONFIG_FILE'))['base_config']['domain'])")
BASE_DN=$(python3 -c "import yaml; print(yaml.safe_load(open('$LDAP_CONFIG_FILE'))['base_config']['base_dn'])")
ADMIN_PASSWORD=$(python3 -c "import yaml; print(yaml.safe_load(open('$LDAP_CONFIG_FILE'))['base_config']['admin_password'])")

# Override with environment variables if available
ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-$ADMIN_PASSWORD}

echo "🔄 Provisioning LDAP with initial configuration..."
echo "   - Domain: $DOMAIN"
echo "   - Base DN: $BASE_DN"

# Create default admin user if running with lldap
if [ -n "$(docker compose ps -q ldap 2>/dev/null)" ]; then
    LDAP_CONTAINER=$(docker compose ps -q ldap)
    LLDAP_IMAGE=$(docker inspect --format='{{.Config.Image}}' $LDAP_CONTAINER)
    
    if [[ "$LLDAP_IMAGE" == *"lldap"* ]]; then
        echo "🔄 Setting up lldap admin account..."
        # Give lldap a moment to initialize its database
        sleep 5
        
        # For lldap, we need to create the admin user through its REST API
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"username\": \"admin\", \"password\": \"$ADMIN_PASSWORD\", \"email\": \"admin@$DOMAIN\", \"display_name\": \"LDAP Administrator\"}" \
            "http://${LDAP_HOST}:17170/api/register" || echo "⚠️ Admin user may already exist"
    fi
fi

echo "✅ LDAP initialization complete."
