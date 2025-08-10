#!/bin/bash
set -e

# Redstone Minikube + Helm Setup Script
# Production-mirroring Kubernetes deployment

echo "🚀 Setting up Redstone on Minikube with Helm..."

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

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v minikube &> /dev/null; then
        print_error "minikube is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Start Minikube with appropriate resources
start_minikube() {
    print_status "Starting Minikube..."
    
    # Check if Minikube is already running
    if minikube status | grep -q "Running"; then
        print_warning "Minikube is already running"
    else
        # Start Minikube with sufficient resources for the stack
        minikube start \
            --cpus=4 \
            --memory=8192 \
            --disk-size=20g \
            --driver=docker \
            --kubernetes-version=v1.28.3
        
        print_success "Minikube started successfully"
    fi
    
    # Enable required addons
    print_status "Enabling Minikube addons..."
    minikube addons enable ingress
    minikube addons enable ingress-dns
    minikube addons enable storage-provisioner
    minikube addons enable default-storageclass
    
    print_success "Minikube addons enabled"
}

# Add Helm repositories
setup_helm_repos() {
    print_status "Setting up Helm repositories..."
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    print_success "Helm repositories configured"
}

# Deploy the Redstone stack
deploy_redstone() {
    print_status "Deploying Redstone stack..."
    
    # Create namespace
    kubectl create namespace redstone --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Helm
    cd "$(dirname "$0")/../helm/redstone"
    
    helm upgrade --install redstone . \
        --namespace redstone \
        --create-namespace \
        --wait \
        --timeout=10m \
        --values values.yaml
    
    print_success "Redstone stack deployed"
}

# Configure local DNS
configure_dns() {
    print_status "Configuring local DNS..."
    
    MINIKUBE_IP=$(minikube ip)
    
    # Add entries to /etc/hosts (requires sudo)
    if ! grep -q "redstone.local" /etc/hosts; then
        print_warning "Adding DNS entries to /etc/hosts (requires sudo)..."
        echo "$MINIKUBE_IP redstone.local" | sudo tee -a /etc/hosts
        echo "$MINIKUBE_IP grafana.local" | sudo tee -a /etc/hosts
    fi
    
    print_success "DNS configured"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/redstone-redmica -n redstone
    kubectl wait --for=condition=available --timeout=600s deployment/redstone-grafana -n redstone
    kubectl wait --for=condition=available --timeout=600s deployment/redstone-loki -n redstone
    
    print_success "All services are ready"
}

# Display access information
show_access_info() {
    print_success "🎉 Redstone deployment completed!"
    echo ""
    echo "Access your services:"
    echo "  📊 Redmica (Project Management): http://redstone.local"
    echo "  📈 Grafana (Monitoring): http://grafana.local"
    echo "     - Username: admin"
    echo "     - Password: admin123"
    echo ""
    echo "Kubernetes Dashboard:"
    echo "  🎛️  Run: minikube dashboard"
    echo ""
    echo "Useful commands:"
    echo "  📋 View pods: kubectl get pods -n redstone"
    echo "  📋 View services: kubectl get svc -n redstone"
    echo "  📋 View logs: kubectl logs -f deployment/redstone-redmica -n redstone"
    echo "  📋 Port forward Grafana: kubectl port-forward svc/redstone-grafana 3000:3000 -n redstone"
    echo ""
    echo "To stop:"
    echo "  🛑 minikube stop"
    echo "  🗑️  minikube delete (to completely remove)"
}

# Main execution
main() {
    echo "🏗️  Redstone Minikube + Helm Setup"
    echo "=================================="
    
    check_prerequisites
    start_minikube
    setup_helm_repos
    deploy_redstone
    configure_dns
    wait_for_services
    show_access_info
}

# Run main function
main "$@"
