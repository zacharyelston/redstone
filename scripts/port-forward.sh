#!/bin/bash

# Port Forward Script for Redstone Services
# This script sets up localhost access to key Redstone services running in Kubernetes

set -e

NAMESPACE="redstone"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.port-forward-pids"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
}

# Function to kill existing port-forwards
cleanup_port_forwards() {
    print_status "Cleaning up existing port-forwards..."
    
    # Kill processes from PID file if it exists
    if [[ -f "$PID_FILE" ]]; then
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                print_status "Killed port-forward process $pid"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Also kill any kubectl port-forward processes
    pkill -f "kubectl.*port-forward.*$NAMESPACE" 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Function to start port-forward in background and store PID
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local description=$4
    
    print_status "Starting port-forward for $description..."
    
    # Check if service exists
    if ! kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
        print_warning "Service '$service' not found in namespace '$NAMESPACE', skipping..."
        return
    fi
    
    # Start port-forward in background
    kubectl port-forward -n "$NAMESPACE" "service/$service" "$local_port:$remote_port" &
    local pid=$!
    
    # Store PID for cleanup
    echo "$pid" >> "$PID_FILE"
    
    # Wait a moment to check if it started successfully
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        print_success "$description available at http://localhost:$local_port"
    else
        print_error "Failed to start port-forward for $description"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [start|stop|restart|status]"
    echo ""
    echo "Commands:"
    echo "  start    - Start all port-forwards"
    echo "  stop     - Stop all port-forwards"
    echo "  restart  - Stop and start all port-forwards"
    echo "  status   - Show status of port-forwards"
    echo ""
    echo "Services and Ports:"
    echo "  Redmica (Redmine):     http://localhost:3001"
    echo "  Grafana:               http://localhost:3002"
    echo "  Prometheus:            http://localhost:9090"
    echo "  LDAP Admin:            ldap://localhost:3890"
}

# Function to show status
show_status() {
    print_status "Port-forward status:"
    
    if [[ ! -f "$PID_FILE" ]]; then
        print_warning "No port-forwards running (PID file not found)"
        return
    fi
    
    local active_count=0
    while read -r pid; do
        if kill -0 "$pid" 2>/dev/null; then
            local cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "Unknown")
            print_success "PID $pid: $cmd"
            ((active_count++))
        fi
    done < "$PID_FILE"
    
    if [[ $active_count -eq 0 ]]; then
        print_warning "No active port-forwards found"
        rm -f "$PID_FILE"
    else
        print_success "$active_count port-forward(s) active"
    fi
}

# Function to start all port-forwards
start_all() {
    check_kubectl
    check_namespace
    
    print_status "Starting port-forwards for Redstone services in namespace '$NAMESPACE'..."
    
    # Create PID file
    touch "$PID_FILE"
    
    # Start port-forwards for each service
    start_port_forward "redmica" "3001" "3000" "Redmica (Redmine)"
    start_port_forward "redstone-grafana" "3002" "3000" "Grafana"
    start_port_forward "redstone-prometheus-server" "9090" "80" "Prometheus"
    start_port_forward "redstone-ldap" "3890" "3890" "LDAP Admin"
    
    echo ""
    print_success "Port-forwards started! Services available at:"
    echo "  Redmica (Redmine):     http://localhost:3001"
    echo "  Grafana:               http://localhost:3002"
    echo "  Prometheus:            http://localhost:9090"
    echo "  LDAP Admin:            ldap://localhost:3890"
    echo ""
    print_status "Use '$0 stop' to stop all port-forwards"
}

# Main script logic
case "${1:-start}" in
    start)
        start_all
        ;;
    stop)
        cleanup_port_forwards
        ;;
    restart)
        cleanup_port_forwards
        sleep 1
        start_all
        ;;
    status)
        show_status
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
