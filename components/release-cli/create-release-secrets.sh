#!/bin/bash

# Redstone Release.com Secrets Creation Script
# This script creates all necessary secrets in Release.com for the Redstone deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/release-secrets.json}"
CREDENTIALS_DIR="${CREDENTIALS_DIR:-$HOME/.redstone/credentials}"

# Global variables
APP_NAME=""
ENV_NAME=""
GENERATE_PASSWORDS=true
DRY_RUN=false

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to generate secure random password
generate_password() {
    local length=${1:-32}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    else
        tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c $length
    fi
}

# Check prerequisites
check_prerequisites() {
    if ! command -v release &> /dev/null; then
        print_error "Release CLI is not installed."
        echo "Install with: npm install -g @release-app/cli"
        echo "Or visit: https://docs.release.com/cli/getting-started"
        exit 1
    fi
    
    if ! release account 2>/dev/null | grep -q "Email:"; then
        print_error "Not authenticated with Release CLI."
        echo "Please run: release login"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Using fallback configuration."
        echo "For better experience, install jq: brew install jq (or apt-get install jq)"
    fi
}

# Load configuration from JSON file or use defaults
load_configuration() {
    if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
        print_status "Loading configuration from $CONFIG_FILE"
        return 0
    else
        print_status "Using default configuration"
        # Create default configuration
        cat > /tmp/release-config.json << 'EOF'
{
  "variables": {
    "configuration": [
      {"name": "ENVIRONMENT", "value": "${ENV_NAME}", "description": "Deployment environment"},
      {"name": "CLUSTER_NAME", "value": "release-${APP_NAME}-${ENV_NAME}", "description": "Cluster identifier"},
      {"name": "LOG_LEVEL", "value": "info", "description": "Application log level"}
    ],
    "services": [
      {"name": "POSTGRES_VERSION", "value": "15-alpine"},
      {"name": "POSTGRES_USER", "value": "postgres"},
      {"name": "POSTGRES_DB", "value": "redmica_production"},
      {"name": "REDIS_VERSION", "value": "7-alpine"},
      {"name": "REDMICA_VERSION", "value": "3.1.7"},
      {"name": "REDMICA_PORT", "value": "3000"},
      {"name": "LDAP_VERSION", "value": "1.5.0"},
      {"name": "LDAP_DOMAIN", "value": "redstone.local"},
      {"name": "LDAP_BASE_DN", "value": "dc=redstone,dc=local"},
      {"name": "LDAP_PORT", "value": "389"},
      {"name": "LDAPS_PORT", "value": "636"},
      {"name": "GRAFANA_VERSION", "value": "10.1.0"},
      {"name": "GRAFANA_PORT", "value": "3002"},
      {"name": "PROMETHEUS_VERSION", "value": "v2.47.0"},
      {"name": "PROMETHEUS_PORT", "value": "9090"},
      {"name": "LOKI_VERSION", "value": "2.9.0"},
      {"name": "LOKI_PORT", "value": "3100"},
      {"name": "PROMTAIL_VERSION", "value": "2.9.0"},
      {"name": "FLUENT_BIT_VERSION", "value": "2.1.8"},
      {"name": "NODE_EXPORTER_VERSION", "value": "v1.6.1"},
      {"name": "NODE_EXPORTER_PORT", "value": "9100"},
      {"name": "POSTGRES_EXPORTER_VERSION", "value": "v0.13.2"},
      {"name": "POSTGRES_EXPORTER_PORT", "value": "9187"},
      {"name": "REDIS_EXPORTER_VERSION", "value": "v1.54.0"},
      {"name": "REDIS_EXPORTER_PORT", "value": "9121"},
      {"name": "BLACKBOX_EXPORTER_VERSION", "value": "v0.24.0"},
      {"name": "BLACKBOX_EXPORTER_PORT", "value": "9115"},
      {"name": "CADVISOR_VERSION", "value": "v0.47.2"},
      {"name": "CADVISOR_PORT", "value": "8080"}
    ],
    "secrets": [
      {"name": "POSTGRES_PASSWORD", "length": 24, "description": "PostgreSQL database password"},
      {"name": "REDIS_PASSWORD", "length": 24, "description": "Redis cache password"},
      {"name": "REDMICA_SECRET_KEY_BASE", "length": 64, "description": "Redmica secret key base"},
      {"name": "LDAP_ADMIN_PASSWORD", "length": 16, "description": "LDAP admin password (min 8 chars)"},
      {"name": "LDAP_CONFIG_PASSWORD", "length": 16, "description": "LDAP configuration password"},
      {"name": "GRAFANA_ADMIN_PASSWORD", "length": 16, "description": "Grafana admin password"},
      {"name": "JWT_SECRET", "length": 64, "description": "JWT secret for authentication"},
      {"name": "SESSION_SECRET", "length": 64, "description": "Session secret for web sessions"}
    ]
  }
}
EOF
        CONFIG_FILE="/tmp/release-config.json"
    fi
}

# Generic function to set environment variable
set_environment_variable() {
    local name=$1
    local value=$2
    local is_secret=${3:-false}
    local description=${4:-""}
    
    [ -n "$description" ] && print_status "$description"
    
    # Replace template variables
    value=$(echo "$value" | sed "s/\${APP_NAME}/$APP_NAME/g" | sed "s/\${ENV_NAME}/$ENV_NAME/g")
    
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Would set $name = ${is_secret:+***hidden***}${is_secret:=$value}"
        return 0
    fi
    
    local secret_flag=""
    [ "$is_secret" = true ] && secret_flag="--secret"
    
    if release env set "$name=$value" --app="$APP_NAME" --env="$ENV_NAME" $secret_flag 2>/dev/null; then
        print_success "${is_secret:+Secret}${is_secret:=Variable} $name created/updated"
    else
        print_error "Failed to create $name"
        return 1
    fi
}

# Process all variables from configuration
process_variables() {
    local category=$1
    local variables
    
    if command -v jq &> /dev/null; then
        variables=$(jq -r ".variables.$category[]" "$CONFIG_FILE" 2>/dev/null)
    else
        # Fallback parsing without jq
        case $category in
            "configuration"|"services")
                # Parse non-secrets
                while IFS= read -r line; do
                    if [[ $line =~ \"name\":\ *\"([^\"]+)\".*\"value\":\ *\"([^\"]+)\" ]]; then
                        local name="${BASH_REMATCH[1]}"
                        local value="${BASH_REMATCH[2]}"
                        set_environment_variable "$name" "$value" false
                    fi
                done < <(grep -A1 "\"$category\":" "$CONFIG_FILE" | grep -E '^\s*\{')
                return
                ;;
        esac
    fi
    
    if command -v jq &> /dev/null; then
        echo "$variables" | jq -c '.' | while IFS= read -r var; do
            local name=$(echo "$var" | jq -r '.name')
            local value=$(echo "$var" | jq -r '.value // empty')
            local description=$(echo "$var" | jq -r '.description // empty')
            
            set_environment_variable "$name" "$value" false "$description"
        done
    fi
}

# Process secrets
process_secrets() {
    local secrets_json
    
    if command -v jq &> /dev/null; then
        secrets_json=$(jq -r '.variables.secrets[]' "$CONFIG_FILE" 2>/dev/null)
    else
        # Simple fallback - just use predefined secrets
        local default_secrets=(
            "POSTGRES_PASSWORD:24:PostgreSQL database password"
            "REDIS_PASSWORD:24:Redis cache password"
            "REDMICA_SECRET_KEY_BASE:64:Redmica secret key base"
            "LDAP_ADMIN_PASSWORD:16:LDAP admin password"
            "LDAP_CONFIG_PASSWORD:16:LDAP configuration password"
            "GRAFANA_ADMIN_PASSWORD:16:Grafana admin password"
            "JWT_SECRET:64:JWT secret"
            "SESSION_SECRET:64:Session secret"
        )
        
        for secret_def in "${default_secrets[@]}"; do
            IFS=':' read -r name length description <<< "$secret_def"
            local value
            
            if [ "$GENERATE_PASSWORDS" = true ]; then
                value=$(generate_password "$length")
            else
                echo ""
                print_status "$description"
                read -p "Enter value for $name (Enter to auto-generate): " value
                [ -z "$value" ] && value=$(generate_password "$length")
            fi
            
            set_environment_variable "$name" "$value" true "$description"
            
            # Store for credential file
            eval "${name}='$value'"
        done
        return
    fi
    
    # Process with jq
    echo "$secrets_json" | jq -c '.' | while IFS= read -r secret; do
        local name=$(echo "$secret" | jq -r '.name')
        local length=$(echo "$secret" | jq -r '.length // 32')
        local description=$(echo "$secret" | jq -r '.description // empty')
        local value
        
        if [ "$GENERATE_PASSWORDS" = true ]; then
            value=$(generate_password "$length")
        else
            echo ""
            print_status "$description"
            read -p "Enter value for $name (Enter to auto-generate): " value
            [ -z "$value" ] && value=$(generate_password "$length")
        fi
        
        set_environment_variable "$name" "$value" true "$description"
        
        # Store for credential file
        eval "${name}='$value'"
    done
}

# Select app and environment
select_app_and_env() {
    print_status "Fetching Release.com applications..."
    
    echo -e "\nAvailable applications:"
    release apps list
    
    echo ""
    read -p "Enter the application name: " APP_NAME
    [ -z "$APP_NAME" ] && { print_error "Application name required"; exit 1; }
    
    print_status "Fetching environments for $APP_NAME..."
    echo -e "\nAvailable environments:"
    release envs list --app="$APP_NAME"
    
    echo ""
    read -p "Enter the environment name: " ENV_NAME
    [ -z "$ENV_NAME" ] && { print_error "Environment name required"; exit 1; }
}

# Save credentials to file
save_credentials() {
    read -p "Save generated credentials locally? (y/N): " save_local
    
    [[ ! $save_local =~ ^[Yy]$ ]] && return
    
    mkdir -p "$CREDENTIALS_DIR"
    local filename="$CREDENTIALS_DIR/redstone-$APP_NAME-$ENV_NAME-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Redstone Release.com Deployment Credentials"
        echo "Generated: $(date)"
        echo "Application: $APP_NAME"
        echo "Environment: $ENV_NAME"
        echo "========================================="
        echo ""
        
        # Output all secrets
        if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
            jq -r '.variables.secrets[].name' "$CONFIG_FILE" | while read -r secret_name; do
                local value="${!secret_name}"
                [ -n "$value" ] && echo "$secret_name=$value"
            done
        else
            # Fallback list
            for var in POSTGRES_PASSWORD REDIS_PASSWORD REDMICA_SECRET_KEY_BASE \
                      LDAP_ADMIN_PASSWORD LDAP_CONFIG_PASSWORD GRAFANA_ADMIN_PASSWORD \
                      JWT_SECRET SESSION_SECRET; do
                [ -n "${!var}" ] && echo "$var=${!var}"
            done
        fi
    } > "$filename"
    
    chmod 600 "$filename"
    print_success "Credentials saved to: $filename"
    print_warning "Keep this file secure and delete after noting the credentials!"
}

# Main function
main() {
    echo "========================================="
    echo "Redstone Release.com Secrets Setup Script"
    echo "========================================="
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true; shift ;;
            --config) CONFIG_FILE="$2"; shift 2 ;;
            --auto) GENERATE_PASSWORDS=true; shift ;;
            --app) APP_NAME="$2"; shift 2 ;;
            --env) ENV_NAME="$2"; shift 2 ;;
            --help) 
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --dry-run         Show what would be done"
                echo "  --config FILE     Use custom configuration file"
                echo "  --auto            Auto-generate all passwords"
                echo "  --app NAME        Specify app name"
                echo "  --env NAME        Specify environment name"
                echo "  --help            Show this help"
                exit 0
                ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Load configuration
    load_configuration
    
    # Show current account
    print_status "Current Release.com account:"
    release account
    echo ""
    
    # Select app and environment if not provided
    [ -z "$APP_NAME" ] || [ -z "$ENV_NAME" ] && select_app_and_env
    
    print_status "Setting up secrets for: $APP_NAME ($ENV_NAME environment)"
    [ "$DRY_RUN" = true ] && print_warning "DRY RUN MODE - No changes will be made"
    echo ""
    
    # Ask about password generation mode if not set
    if [ -z "$GENERATE_PASSWORDS" ]; then
        read -p "Auto-generate all passwords? (Y/n): " auto_mode
        [[ ! $auto_mode =~ ^[Nn]$ ]] && GENERATE_PASSWORDS=true || GENERATE_PASSWORDS=false
    fi
    
    # Process all variable categories
    print_status "Creating configuration variables..."
    process_variables "configuration"
    
    print_status "Creating service variables..."
    process_variables "services"
    
    print_status "Creating secrets..."
    process_secrets
    
    # Add Release-specific variables
    set_environment_variable "RELEASE_PROJECT_NAME" "$APP_NAME" false
    set_environment_variable "RELEASE_ENVIRONMENT" "$ENV_NAME" false
    
    echo ""
    print_success "All variables have been processed!"
    echo ""
    
    # Show summary
    print_status "View your environment variables with:"
    echo "  release env list --app=\"$APP_NAME\" --env=\"$ENV_NAME\""
    echo ""
    
    # Save credentials if not dry run
    [ "$DRY_RUN" = false ] && save_credentials
    
    print_success "Setup complete!"
    echo -e "\nNext steps:"
    echo "1. Commit and push to trigger deployment"
    echo "2. Monitor: release status --app=\"$APP_NAME\""
    echo "3. View logs: release logs --app=\"$APP_NAME\" --env=\"$ENV_NAME\""
}

# Run main function
main "$@"
