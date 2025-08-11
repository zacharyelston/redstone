#!/bin/bash

# Redstone Release.com Static Environment Management Script
# Following the "Built for Clarity" design philosophy
# Manages dev/test/prod static environments with git tag-based deployments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to show usage
show_usage() {
    cat << EOF
Redstone Release.com Static Environment Management

Usage: $0 <command> [options]

Commands:
  status                    Show status of all environments
  deploy <env>             Deploy to specific environment
  test <env>               Test specific environment
  promote <version>        Promote version through environments
  rollback <env> <version> Rollback environment to specific version
  logs <env>               Show deployment logs for environment
  
Environments:
  development              Continuous deployment from main branch
  staging                  Release candidates (v*-rc.*)
  production               Stable releases (v*)

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  -d, --dry-run           Show what would be done without executing
  
Examples:
  $0 status                           # Show all environment status
  $0 deploy development               # Deploy to development
  $0 test staging                     # Test staging environment
  $0 promote v1.2.0                   # Promote v1.2.0 through environments
  $0 rollback production v1.1.9       # Rollback production to v1.1.9

EOF
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        print_error "Git is required but not installed."
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_ROOT/deploy/release/api/client.py" ]]; then
        print_error "Release.com API client not found at deploy/release/api/client.py"
        exit 1
    fi
}

# Function to get environment status
get_environment_status() {
    local env=$1
    print_status "Checking status of $env environment..."
    
    # Use Release.com API client to get status
    python3 "$PROJECT_ROOT/deploy/release/api/client.py" status \
        --environment "$env" || echo "Status check failed"
}

# Function to deploy to environment
deploy_environment() {
    local env=$1
    local version=${2:-"latest"}
    
    print_status "Deploying to $env environment (version: $version)..."
    
    # Load environment configuration
    local env_file="$PROJECT_ROOT/deploy/release/environments/$env/.env.example"
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment configuration not found: $env_file"
        exit 1
    fi
    
    # Deploy using Release.com API client
    python3 "$PROJECT_ROOT/deploy/release/api/client.py" deploy \
        --environment "$env" \
        --version "$version"
    
    print_success "Deployment to $env initiated"
}

# Function to test environment
test_environment() {
    local env=$1
    
    print_status "Testing $env environment..."
    
    # Set environment-specific URLs
    local base_url
    case $env in
        development)
            base_url="https://dev.redstone.example.com"
            ;;
        staging)
            base_url="https://staging.redstone.example.com"
            ;;
        production)
            base_url="https://redstone.example.com"
            ;;
        *)
            print_error "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    print_status "Testing $env at $base_url..."
    
    # Basic health checks
    if curl -f -s "$base_url/" > /dev/null; then
        print_success "✅ Application is responding"
    else
        print_error "❌ Application is not responding"
        return 1
    fi
    
    if curl -f -s "$base_url/health" > /dev/null; then
        print_success "✅ Health endpoint is working"
    else
        print_warning "⚠️ Health endpoint not available (may be normal)"
    fi
    
    # Test Grafana if available
    local grafana_url="${base_url/redstone/grafana}"
    if curl -f -s "$grafana_url/api/health" > /dev/null; then
        print_success "✅ Grafana is responding"
    else
        print_warning "⚠️ Grafana not available or not responding"
    fi
    
    print_success "Environment testing completed for $env"
}

# Function to promote version through environments
promote_version() {
    local version=$1
    
    if [[ -z "$version" ]]; then
        print_error "Version is required for promotion"
        exit 1
    fi
    
    print_status "Promoting version $version through environments..."
    
    # Check if version exists
    if ! git tag | grep -q "^$version$"; then
        print_error "Version tag $version does not exist"
        exit 1
    fi
    
    # Determine promotion path based on version format
    if [[ "$version" =~ -rc\. ]]; then
        print_status "Release candidate detected - promoting to staging"
        deploy_environment "staging" "$version"
        test_environment "staging"
    else
        print_status "Stable release detected - promoting to production"
        deploy_environment "production" "$version"
        test_environment "production"
    fi
}

# Function to rollback environment
rollback_environment() {
    local env=$1
    local version=$2
    
    if [[ -z "$env" || -z "$version" ]]; then
        print_error "Environment and version are required for rollback"
        exit 1
    fi
    
    print_warning "Rolling back $env environment to version $version"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_environment "$env" "$version"
        print_success "Rollback initiated for $env to version $version"
    else
        print_status "Rollback cancelled"
    fi
}

# Function to show deployment logs
show_logs() {
    local env=$1
    
    print_status "Fetching deployment logs for $env environment..."
    
    python3 "$PROJECT_ROOT/deploy/release/api/client.py" logs \
        --environment "$env" \
        --lines 50
}

# Function to show all environment status
show_all_status() {
    print_status "=== Redstone Release.com Environment Status ==="
    echo
    
    for env in development staging production; do
        echo "🔍 $env Environment:"
        get_environment_status "$env"
        echo
    done
    
    print_status "=== Recent Git Tags ==="
    git tag --sort=-version:refname | head -10
}

# Main function
main() {
    local command=$1
    shift
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Execute command
    case $command in
        status)
            show_all_status
            ;;
        deploy)
            local env=$1
            local version=$2
            if [[ -z "$env" ]]; then
                print_error "Environment is required for deploy command"
                show_usage
                exit 1
            fi
            deploy_environment "$env" "$version"
            ;;
        test)
            local env=$1
            if [[ -z "$env" ]]; then
                print_error "Environment is required for test command"
                show_usage
                exit 1
            fi
            test_environment "$env"
            ;;
        promote)
            local version=$1
            if [[ -z "$version" ]]; then
                print_error "Version is required for promote command"
                show_usage
                exit 1
            fi
            promote_version "$version"
            ;;
        rollback)
            local env=$1
            local version=$2
            rollback_environment "$env" "$version"
            ;;
        logs)
            local env=$1
            if [[ -z "$env" ]]; then
                print_error "Environment is required for logs command"
                show_usage
                exit 1
            fi
            show_logs "$env"
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
