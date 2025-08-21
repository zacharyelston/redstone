#!/bin/bash

# Minikube Local Testing Script for Redstone Grafana Provisioning
# Tests the complete Helm deployment locally to validate configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="redstone-test"
RELEASE_NAME="redstone-local"
GRAFANA_PORT=3000

echo -e "${BLUE}=== Minikube Redstone Deployment Test ===${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites${NC}"
for cmd in minikube kubectl helm; do
    if command_exists "$cmd"; then
        echo -e "${GREEN}✓ $cmd is installed${NC}"
    else
        echo -e "${RED}✗ $cmd is not installed${NC}"
        echo "Please install $cmd before running this script"
        exit 1
    fi
done

# Check if minikube is running
echo -e "${YELLOW}Step 2: Checking Minikube Status${NC}"
if minikube status | grep -q "Running"; then
    echo -e "${GREEN}✓ Minikube is running${NC}"
else
    echo -e "${YELLOW}! Starting Minikube...${NC}"
    minikube start --memory=4096 --cpus=2
    echo -e "${GREEN}✓ Minikube started${NC}"
fi

# Create namespace
echo -e "${YELLOW}Step 3: Setting up Namespace${NC}"
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo -e "${YELLOW}! Namespace $NAMESPACE already exists, cleaning up...${NC}"
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    sleep 5
fi

kubectl create namespace "$NAMESPACE"
echo -e "${GREEN}✓ Created namespace: $NAMESPACE${NC}"

# Update Helm dependencies
echo -e "${YELLOW}Step 4: Updating Helm Dependencies${NC}"
cd helm/redstone
if helm dependency update; then
    echo -e "${GREEN}✓ Helm dependencies updated${NC}"
else
    echo -e "${RED}✗ Failed to update Helm dependencies${NC}"
    exit 1
fi

# Deploy with Helm
echo -e "${YELLOW}Step 5: Deploying Redstone with Helm${NC}"
echo "Installing Helm chart..."
if helm install "$RELEASE_NAME" . --namespace "$NAMESPACE" --wait --timeout=10m; then
    echo -e "${GREEN}✓ Helm deployment successful${NC}"
else
    echo -e "${RED}✗ Helm deployment failed${NC}"
    echo "Checking deployment status..."
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi

# Wait for pods to be ready
echo -e "${YELLOW}Step 6: Waiting for Pods to be Ready${NC}"
echo "Waiting for all pods to be ready..."
if kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=300s; then
    echo -e "${GREEN}✓ All pods are ready${NC}"
else
    echo -e "${RED}✗ Some pods failed to become ready${NC}"
    kubectl get pods -n "$NAMESPACE"
    echo "Pod logs for debugging:"
    kubectl logs -l app.kubernetes.io/name=grafana -n "$NAMESPACE" --tail=20
fi

# Check ConfigMaps
echo -e "${YELLOW}Step 7: Verifying ConfigMaps${NC}"
expected_configmaps=(
    "redstone-grafana-datasources"
    "redstone-grafana-dashboards"
    "redstone-grafana-dashboard-metrics"
    "redstone-grafana-dashboard-working"
)

for configmap in "${expected_configmaps[@]}"; do
    if kubectl get configmap "$configmap" -n "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ConfigMap exists: $configmap${NC}"
        
        # Show ConfigMap size
        size=$(kubectl get configmap "$configmap" -n "$NAMESPACE" -o jsonpath='{.data}' | wc -c)
        echo "    Size: ${size} bytes"
    else
        echo -e "${RED}✗ ConfigMap missing: $configmap${NC}"
    fi
done

# Port forward Grafana
echo -e "${YELLOW}Step 8: Setting up Port Forward to Grafana${NC}"
echo "Setting up port forward to Grafana..."
kubectl port-forward -n "$NAMESPACE" svc/redstone-grafana 3000:80 &
PORT_FORWARD_PID=$!

# Wait for port forward to be ready
sleep 5

# Function to cleanup on exit
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    if [ -n "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Test Grafana connectivity
echo -e "${YELLOW}Step 9: Testing Grafana Connectivity${NC}"
GRAFANA_URL="http://localhost:3000"
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Grafana is accessible at $GRAFANA_URL${NC}"
        break
    else
        echo "Attempt $attempt/$max_attempts: Waiting for Grafana to be ready..."
        sleep 2
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}✗ Grafana is not accessible after $max_attempts attempts${NC}"
    echo "Checking Grafana pod logs:"
    kubectl logs -l app.kubernetes.io/name=grafana -n "$NAMESPACE" --tail=50
    exit 1
fi

# Run Grafana provisioning test
echo -e "${YELLOW}Step 10: Testing Grafana Provisioning${NC}"
cd ../../  # Back to project root

# Get admin password from secret
ADMIN_PASSWORD=$(kubectl get secret redstone-grafana -n "$NAMESPACE" -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Admin password: $ADMIN_PASSWORD"

# Run the provisioning test
if GRAFANA_URL="$GRAFANA_URL" GRAFANA_USER="admin" GRAFANA_PASS="$ADMIN_PASSWORD" ./scripts/test-grafana-provisioning.sh; then
    echo -e "${GREEN}✓ Grafana provisioning test passed${NC}"
else
    echo -e "${RED}✗ Grafana provisioning test failed${NC}"
    echo ""
    echo -e "${YELLOW}Debugging Information:${NC}"
    
    # Check ConfigMap mounts in Grafana pod
    echo "Checking ConfigMap mounts in Grafana pod:"
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -- ls -la /etc/grafana/provisioning/datasources/ || echo "Datasources directory not found"
    kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -- ls -la /var/lib/grafana/dashboards/ || echo "Dashboards directory not found"
    
    # Check Grafana logs
    echo ""
    echo "Recent Grafana logs:"
    kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" --tail=20
fi

# Summary
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Grafana URL: $GRAFANA_URL"
echo "Admin Password: $ADMIN_PASSWORD"
echo ""
echo -e "${YELLOW}Manual Testing:${NC}"
echo "1. Open browser to: $GRAFANA_URL"
echo "2. Login with admin / $ADMIN_PASSWORD"
echo "3. Check Connections > Data sources"
echo "4. Check Dashboards > Browse > Redstone folder"
echo ""
echo -e "${YELLOW}Cleanup Commands:${NC}"
echo "helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo "kubectl delete namespace $NAMESPACE"
echo ""
echo "Press Ctrl+C to stop port forwarding and cleanup"

# Keep port forward running for manual testing
wait $PORT_FORWARD_PID
