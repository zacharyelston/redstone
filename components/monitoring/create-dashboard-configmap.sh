#!/bin/bash
# Script to create Grafana dashboard ConfigMap from dashboard files
# This populates the ConfigMap with actual dashboard JSON files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/grafana/dashboards"
NAMESPACE="redstone"
CONFIGMAP_NAME="redstone-grafana-dashboards"

echo "Creating Grafana dashboard ConfigMap..."
echo "Dashboard directory: $DASHBOARD_DIR"
echo "ConfigMap name: $CONFIGMAP_NAME"
echo "Namespace: $NAMESPACE"

# Check if dashboard directory exists
if [[ ! -d "$DASHBOARD_DIR" ]]; then
    echo "Error: Dashboard directory not found: $DASHBOARD_DIR"
    exit 1
fi

# Count dashboard files
DASHBOARD_COUNT=$(find "$DASHBOARD_DIR" -name "*.json" | wc -l)
if [[ $DASHBOARD_COUNT -eq 0 ]]; then
    echo "Error: No dashboard JSON files found in $DASHBOARD_DIR"
    exit 1
fi

echo "Found $DASHBOARD_COUNT dashboard files"

# Create ConfigMap from dashboard files
kubectl create configmap "$CONFIGMAP_NAME" \
    --from-file="$DASHBOARD_DIR" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml > /tmp/dashboard-configmap.yaml

# Apply the ConfigMap
kubectl apply -f /tmp/dashboard-configmap.yaml

echo "✓ Dashboard ConfigMap created successfully"
echo "✓ ConfigMap contains $(kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys | length') dashboard files"

# Clean up temp file
rm -f /tmp/dashboard-configmap.yaml
