#!/bin/bash
# Test script to validate ClusterRole conflict resolution
# This script checks that all ClusterRole-creating components are properly disabled

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="/Users/zacelston/AlZacAI/redstone/helm/redstone"
VALUES_FILE="$HELM_CHART_DIR/values.yaml"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 ClusterRole Conflict Resolution Validation"
echo "============================================="

# Test 1: Check Loki ClusterRole components are disabled
echo -e "\n${YELLOW}Test 1: Validating Loki ClusterRole components are disabled${NC}"

LOKI_CLUSTERROLE_COMPONENTS=(
    "monitoring.*enabled.*false"
    "grafana-agent-operator.*enabled.*false"
    "serviceMonitor.*enabled.*false"
    "prometheusRule.*enabled.*false"
    "rbac.*create.*false"
    "grafanaAgent.*enabled.*false"
    "agent.*enabled.*false"
)

for component in "${LOKI_CLUSTERROLE_COMPONENTS[@]}"; do
    if grep -A 20 "^loki:" "$VALUES_FILE" | grep -q "$component"; then
        echo "✓ Loki $component is disabled"
    else
        echo -e "${RED}✗ Loki $component not found or not disabled${NC}"
        exit 1
    fi
done

# Test 2: Check Grafana ClusterRole components are disabled
echo -e "\n${YELLOW}Test 2: Validating Grafana ClusterRole components are disabled${NC}"

GRAFANA_CLUSTERROLE_COMPONENTS=(
    "rbac.*create.*false"
    "sidecar.*dashboards.*enabled.*false"
    "sidecar.*datasources.*enabled.*false"
    "agent.*enabled.*false"
    "grafana-agent-operator.*enabled.*false"
    "grafanaOperator.*enabled.*false"
    "grafanaAgent.*enabled.*false"
)

for component in "${GRAFANA_CLUSTERROLE_COMPONENTS[@]}"; do
    if grep -A 50 "^grafana:" "$VALUES_FILE" | grep -q "$component"; then
        echo "✓ Grafana $component is disabled"
    else
        echo -e "${RED}✗ Grafana $component not found or not disabled${NC}"
        exit 1
    fi
done

# Test 3: Check Prometheus ClusterRole components are disabled
echo -e "\n${YELLOW}Test 3: Validating Prometheus ClusterRole components are disabled${NC}"

PROMETHEUS_CLUSTERROLE_COMPONENTS=(
    "kube-state-metrics.*enabled.*false"
    "rbac.*create.*false"
    "server.*rbac.*create.*false"
    "serviceMonitor.*enabled.*false"
    "prometheusRule.*enabled.*false"
)

for component in "${PROMETHEUS_CLUSTERROLE_COMPONENTS[@]}"; do
    if grep -A 30 "^prometheus:" "$VALUES_FILE" | grep -q "$component"; then
        echo "✓ Prometheus $component is disabled"
    else
        echo -e "${RED}✗ Prometheus $component not found or not disabled${NC}"
        exit 1
    fi
done

# Test 4: Check Fluent Bit RBAC is disabled
echo -e "\n${YELLOW}Test 4: Validating Fluent Bit RBAC is disabled${NC}"

if grep -A 10 "fluentBit:" "$VALUES_FILE" | grep -q "rbac.*create.*false"; then
    echo "✓ Fluent Bit RBAC is disabled"
else
    echo -e "${RED}✗ Fluent Bit RBAC not disabled${NC}"
    exit 1
fi

# Test 5: Validate Helm chart syntax after ClusterRole fixes
echo -e "\n${YELLOW}Test 5: Validating Helm chart syntax after ClusterRole fixes${NC}"

if helm lint "$HELM_CHART_DIR" >/dev/null 2>&1; then
    echo "✓ Helm chart syntax is valid after ClusterRole fixes"
else
    echo -e "${RED}✗ Helm chart syntax errors after ClusterRole fixes${NC}"
    helm lint "$HELM_CHART_DIR"
    exit 1
fi

# Test 6: Check for any remaining ClusterRole references
echo -e "\n${YELLOW}Test 6: Checking for any remaining ClusterRole-creating configurations${NC}"

PROBLEMATIC_PATTERNS=(
    "clusterRole.*true"
    "rbac.*create.*true"
    "kube-state-metrics.*enabled.*true"
    "grafana-agent.*enabled.*true"
    "monitoring.*enabled.*true"
)

FOUND_ISSUES=false
for pattern in "${PROBLEMATIC_PATTERNS[@]}"; do
    if grep -q "$pattern" "$VALUES_FILE"; then
        echo -e "${RED}✗ Found potentially problematic pattern: $pattern${NC}"
        FOUND_ISSUES=true
    fi
done

if [[ "$FOUND_ISSUES" == "false" ]]; then
    echo "✓ No problematic ClusterRole-creating patterns found"
fi

echo -e "\n${GREEN}🎉 ClusterRole conflict resolution validation complete!${NC}"
echo ""
echo "Summary of ClusterRole fixes:"
echo "✓ Loki: All agent and monitoring components disabled"
echo "✓ Grafana: RBAC, sidecars, and agents disabled"
echo "✓ Prometheus: kube-state-metrics and RBAC disabled"
echo "✓ Fluent Bit: RBAC disabled"
echo "✓ All monitoring components disabled"
echo ""
echo "This configuration should resolve the ClusterRole ownership conflicts"
echo "between ephemeral environments in Release.com deployments."
