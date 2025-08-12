#!/bin/bash

# Redstone Release.com Tools - Containerized Wrapper
# Following the "Built for Clarity" design philosophy
# Portable execution of Release.com API client and management tools

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
CONTAINER_NAME="redstone-release-tools"
IMAGE_NAME="redstone/release-tools"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to show usage
show_usage() {
    cat << EOF
Redstone Release.com Tools - Containerized Wrapper

Usage: $0 <command> [options]

Commands:
  build                     Build the Release.com tools container
  status                    Show status of all environments
  deploy <env>             Deploy to specific environment
  test <env>               Test specific environment
  promote <version>        Promote version through environments
  rollback <env> <version> Rollback environment to specific version
  logs <env>               Show deployment logs for environment
  shell                    Open interactive shell in container
  clean                    Remove container and image

Environment Variables:
  RELEASE_API_TOKEN        Release.com API token (required)
  RELEASE_DEV_APP_ID       Development app ID
  RELEASE_STAGING_APP_ID   Staging app ID  
  RELEASE_PROD_APP_ID      Production app ID
  RELEASE_DEV_ENV_ID       Development environment ID
  RELEASE_STAGING_ENV_ID   Staging environment ID
  RELEASE_PROD_ENV_ID      Production environment ID

Examples:
  $0 build                           # Build container image
  $0 status                          # Check all environment status
  $0 deploy development              # Deploy to development
  $0 test staging                    # Test staging environment
  $0 promote v1.2.0                  # Promote version through environments
  $0 shell                           # Interactive container shell

EOF
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not installed."
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_ROOT/deploy/release/Dockerfile" ]]; then
        print_error "Release.com tools Dockerfile not found."
        exit 1
    fi
}

# Function to build container image
build_container() {
    print_status "Building Release.com tools container..."
    
    cd "$PROJECT_ROOT/deploy/release"
    
    # Build the container image
    docker build -t "$IMAGE_NAME" . || {
        print_error "Failed to build container image"
        exit 1
    }
    
    print_success "Container image built successfully: $IMAGE_NAME"
}

# Function to run containerized command
run_containerized() {
    local command="$1"
    shift
    local args="$@"
    
    # Check if image exists
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_warning "Container image not found. Building..."
        build_container
    fi
    
    # Prepare environment variables for container
    local env_vars=""
    
    # Add Release.com API credentials if available
    if [[ -n "$RELEASE_API_TOKEN" ]]; then
        env_vars="$env_vars -e RELEASE_API_TOKEN=$RELEASE_API_TOKEN"
    fi
    
    if [[ -n "$RELEASE_DEV_APP_ID" ]]; then
        env_vars="$env_vars -e RELEASE_DEV_APP_ID=$RELEASE_DEV_APP_ID"
    fi
    
    if [[ -n "$RELEASE_STAGING_APP_ID" ]]; then
        env_vars="$env_vars -e RELEASE_STAGING_APP_ID=$RELEASE_STAGING_APP_ID"
    fi
    
    if [[ -n "$RELEASE_PROD_APP_ID" ]]; then
        env_vars="$env_vars -e RELEASE_PROD_APP_ID=$RELEASE_PROD_APP_ID"
    fi
    
    if [[ -n "$RELEASE_DEV_ENV_ID" ]]; then
        env_vars="$env_vars -e RELEASE_DEV_ENV_ID=$RELEASE_DEV_ENV_ID"
    fi
    
    if [[ -n "$RELEASE_STAGING_ENV_ID" ]]; then
        env_vars="$env_vars -e RELEASE_STAGING_ENV_ID=$RELEASE_STAGING_ENV_ID"
    fi
    
    if [[ -n "$RELEASE_PROD_ENV_ID" ]]; then
        env_vars="$env_vars -e RELEASE_PROD_ENV_ID=$RELEASE_PROD_ENV_ID"
    fi
    
    # Run the containerized command
    print_status "Running containerized command: $command $args"
    
    case $command in
        shell)
            docker run --rm -it $env_vars \
                -v "$PROJECT_ROOT:/workspace" \
                -v "$PROJECT_ROOT/scripts:/app/scripts" \
                --name "$CONTAINER_NAME" \
                "$IMAGE_NAME" /bin/bash
            ;;
        status|deploy|test|promote|rollback|logs)
            docker run --rm $env_vars \
                -v "$PROJECT_ROOT:/workspace" \
                -v "$PROJECT_ROOT/scripts:/app/scripts" \
                --workdir /workspace \
                --name "$CONTAINER_NAME" \
                "$IMAGE_NAME" /app/scripts/manage-release-environments.sh "$command" $args
            ;;
        api)
            docker run --rm $env_vars \
                -v "$PROJECT_ROOT:/workspace" \
                -v "$PROJECT_ROOT/scripts:/app/scripts" \
                --name "$CONTAINER_NAME" \
                "$IMAGE_NAME" python api/client.py $args
            ;;
        test-deployment)
            docker run --rm $env_vars \
                -v "$PROJECT_ROOT:/workspace" \
                -v "$PROJECT_ROOT/scripts:/app/scripts" \
                --name "$CONTAINER_NAME" \
                "$IMAGE_NAME" /app/scripts/test-release-deployment.sh $args
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Function to clean up container and image
clean_container() {
    print_status "Cleaning up Release.com tools container..."
    
    # Stop and remove container if running
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        print_status "Stopping running container..."
        docker stop "$CONTAINER_NAME" || true
    fi
    
    # Remove container if exists
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        print_status "Removing container..."
        docker rm "$CONTAINER_NAME" || true
    fi
    
    # Remove image if exists
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_status "Removing container image..."
        docker rmi "$IMAGE_NAME" || true
    fi
    
    print_success "Cleanup completed"
}

# Main function
main() {
    local command="$1"
    shift || true
    
    # Check prerequisites
    check_prerequisites
    
    # Handle commands
    case $command in
        -h|--help|help|"")
            show_usage
            exit 0
            ;;
        build)
            build_container
            ;;
        clean)
            clean_container
            ;;
        status|deploy|test|promote|rollback|logs|shell|api|test-deployment)
            run_containerized "$command" "$@"
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
