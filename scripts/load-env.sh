#!/bin/bash
# Redstone Environment Loader
# Following the "Built for Clarity" design philosophy
# Loads environment variables from .env file for testing and development

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Load environment variables from .env file and export them to the current shell.

OPTIONS:
    -h, --help      Show this help message
    -f, --file      Specify custom .env file path (default: .env)
    -v, --verbose   Show all exported variables
    -d, --dry-run   Show what would be exported without actually exporting
    -s, --source    Generate source-able output (for use with 'source' command)

EXAMPLES:
    # Load environment variables
    $0

    # Load with verbose output
    $0 --verbose

    # Source the variables into current shell
    source <($0 --source)

    # Dry run to see what would be exported
    $0 --dry-run

EOF
}

# Parse command line arguments
VERBOSE=false
DRY_RUN=false
SOURCE_MODE=false
CUSTOM_ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--file)
            CUSTOM_ENV_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--source)
            SOURCE_MODE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Use custom env file if specified
if [[ -n "$CUSTOM_ENV_FILE" ]]; then
    ENV_FILE="$CUSTOM_ENV_FILE"
fi

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    print_error ".env file not found at: $ENV_FILE"
    print_warning "You can create one by copying .env.example:"
    echo "  cp .env.example .env"
    exit 1
fi

# Function to process and export environment variables
load_env_vars() {
    local count=0
    local exported_vars=()

    print_status "Loading environment variables from: $ENV_FILE"

    # Read the .env file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Skip lines that don't contain '='
        if [[ ! "$line" =~ = ]]; then
            continue
        fi

        # Extract key and value
        key="${line%%=*}"
        value="${line#*=}"

        # Remove leading/trailing whitespace from key
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Skip if key is empty
        if [[ -z "$key" ]]; then
            continue
        fi

        # Remove quotes from value if present
        if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
            value="${value:1:-1}"
        fi

        # In source mode, just output the export statement
        if [[ "$SOURCE_MODE" == true ]]; then
            echo "export $key=\"$value\""
            continue
        fi

        # In dry-run mode, just show what would be exported
        if [[ "$DRY_RUN" == true ]]; then
            echo "$key=$value"
            ((count++))
            continue
        fi

        # Export the variable
        export "$key"="$value"
        exported_vars+=("$key")
        ((count++))

        # Show variable if verbose mode
        if [[ "$VERBOSE" == true ]]; then
            echo "  $key=$value"
        fi

    done < "$ENV_FILE"

    # Don't print summary in source mode
    if [[ "$SOURCE_MODE" == true ]]; then
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_success "Would export $count environment variables"
    else
        print_success "Exported $count environment variables"
        
        if [[ "$VERBOSE" == false && $count -gt 0 ]]; then
            print_status "Use --verbose to see all exported variables"
        fi
    fi

    # Show some key variables for verification
    if [[ "$DRY_RUN" == false && "$VERBOSE" == false && $count -gt 0 ]]; then
        print_status "Key variables loaded:"
        for var in "ENVIRONMENT" "CLUSTER_NAME" "REDMICA_VERSION" "POSTGRES_VERSION"; do
            if [[ -n "${!var:-}" ]]; then
                echo "  $var=${!var}"
            fi
        done
    fi
}

# Function to verify environment is loaded
verify_environment() {
    if [[ "$SOURCE_MODE" == true || "$DRY_RUN" == true ]]; then
        return
    fi

    print_status "Environment verification:"
    
    # Check critical variables
    local critical_vars=("ENVIRONMENT" "POSTGRES_PASSWORD" "REDMICA_SECRET_KEY_BASE")
    local missing_vars=()
    
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_warning "Missing critical variables: ${missing_vars[*]}"
        print_warning "Consider updating your .env file"
    else
        print_success "All critical variables are set"
    fi
}

# Main execution
main() {
    if [[ "$SOURCE_MODE" == false ]]; then
        print_status "Redstone Environment Loader"
        echo
    fi

    load_env_vars
    verify_environment

    if [[ "$SOURCE_MODE" == false && "$DRY_RUN" == false ]]; then
        echo
        print_success "Environment loaded successfully!"
        print_status "You can now run other Redstone tools with these environment variables"
        echo
        print_status "To source these variables in your current shell, run:"
        echo "  source <($0 --source)"
    fi
}

# Run main function
main "$@"
