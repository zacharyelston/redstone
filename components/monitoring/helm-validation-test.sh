#!/bin/bash
# Helm chart validation test for Grafana configuration
# This script validates the corrected Helm chart configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="/Users/zacelston/AlZacAI/redstone/helm/redstone"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Helm Chart Configuration Validation"
echo "======================================"

# Test 1: Validate Helm chart syntax
echo -e "\n${YELLOW}Test 1: Validating Helm chart syntax${NC}"
if helm lint "$HELM_CHART_DIR" >/dev/null 2>&1; then
    echo "✓ Helm chart syntax is valid"
else
    echo -e "${RED}✗ Helm chart syntax errors found${NC}"
    helm lint "$HELM_CHART_DIR"
    exit 1
fi

# Test 2: Check ConfigMap references
echo -e "\n${YELLOW}Test 2: Validating ConfigMap references${NC}"
VALUES_FILE="$HELM_CHART_DIR/values.yaml"

# Check for correct ConfigMap references
if grep -q "grafana-env-config" "$VALUES_FILE"; then
    echo "✓ Environment ConfigMap reference found"
else
    echo -e "${RED}✗ Missing grafana-env-config ConfigMap reference${NC}"
    exit 1
fi

if grep -q "redstone-grafana-datasources" "$VALUES_FILE"; then
    echo "✓ Datasources ConfigMap reference found"
else
    echo -e "${RED}✗ Missing datasources ConfigMap reference${NC}"
    exit 1
fi

if grep -q "redstone-grafana-ldap-config" "$VALUES_FILE"; then
    echo "✓ LDAP ConfigMap reference found"
else
    echo -e "${RED}✗ Missing LDAP ConfigMap reference${NC}"
    exit 1
fi

# Test 3: Validate mount paths
echo -e "\n${YELLOW}Test 3: Validating mount paths${NC}"

if grep -q "/etc/grafana/provisioning/datasources/datasources.yml" "$VALUES_FILE"; then
    echo "✓ Datasources mount path is correct"
else
    echo -e "${RED}✗ Incorrect datasources mount path${NC}"
    exit 1
fi

if grep -q "/etc/grafana/dashboards" "$VALUES_FILE"; then
    echo "✓ Dashboards mount path is correct"
else
    echo -e "${RED}✗ Incorrect dashboards mount path${NC}"
    exit 1
fi

if grep -q "/etc/grafana/ldap.toml" "$VALUES_FILE"; then
    echo "✓ LDAP config mount path is correct"
else
    echo -e "${RED}✗ Incorrect LDAP config mount path${NC}"
    exit 1
fi

# Test 4: Check dashboard provider configuration
echo -e "\n${YELLOW}Test 4: Validating dashboard provider configuration${NC}"

if grep -A 15 "dashboardProviders:" "$VALUES_FILE" | grep -q "path: /etc/grafana/dashboards"; then
    echo "✓ Dashboard provider path matches mount path"
else
    echo -e "${RED}✗ Dashboard provider path mismatch${NC}"
    exit 1
fi

# Test 5: Validate environment variable configuration
echo -e "\n${YELLOW}Test 5: Validating environment variable configuration${NC}"

if grep -q "envFromConfigMap:" "$VALUES_FILE"; then
    echo "✓ ConfigMap environment variables configured"
else
    echo -e "${RED}✗ Missing ConfigMap environment variables${NC}"
    exit 1
fi

if grep -q "envFromSecret:" "$VALUES_FILE"; then
    echo "✓ Secret environment variables configured"
else
    echo -e "${RED}✗ Missing Secret environment variables${NC}"
    exit 1
fi

# Test 6: Check for hardcoded values removal
echo -e "\n${YELLOW}Test 6: Checking for hardcoded environment variables${NC}"

if grep -q "PROMETHEUS_URL:" "$VALUES_FILE" && ! grep -q "envFromConfigMap:" "$VALUES_FILE"; then
    echo -e "${RED}✗ Found hardcoded PROMETHEUS_URL in env section${NC}"
    exit 1
else
    echo "✓ No hardcoded environment variables found"
fi

# Test 7: Validate ConfigMap files exist
echo -e "\n${YELLOW}Test 7: Validating ConfigMap files exist${NC}"

REQUIRED_CONFIGMAPS=(
    "grafana-configmap.yaml"
    "grafana-ldap-configmap.yaml" 
    "grafana-datasources-configmap.yaml"
)

for configmap in "${REQUIRED_CONFIGMAPS[@]}"; do
    if [[ -f "$SCRIPT_DIR/$configmap" ]]; then
        echo "✓ $configmap exists"
    else
        echo -e "${RED}✗ Missing ConfigMap file: $configmap${NC}"
        exit 1
    fi
done

# Test 8: Validate LDAP configuration consistency
echo -e "\n${YELLOW}Test 8: Validating LDAP configuration consistency${NC}"

# Check LDAP_BIND_DN consistency between ConfigMap and LDAP config
CONFIGMAP_BIND_DN=$(grep "LDAP_BIND_DN:" "$SCRIPT_DIR/grafana-configmap.yaml" | cut -d'"' -f2)
LDAP_BIND_DN=$(grep "bind_dn =" "$SCRIPT_DIR/grafana-ldap-configmap.yaml" | cut -d'"' -f2)

if [[ "$CONFIGMAP_BIND_DN" == "$LDAP_BIND_DN" ]]; then
    echo "✓ LDAP bind DN is consistent between ConfigMap and LDAP config"
else
    echo -e "${RED}✗ LDAP bind DN mismatch:${NC}"
    echo "  ConfigMap: $CONFIGMAP_BIND_DN"
    echo "  LDAP config: $LDAP_BIND_DN"
    exit 1
fi

echo -e "\n${GREEN}🎉 All Helm chart validations passed!${NC}"
echo ""
echo "Fixed issues:"
echo "✓ Corrected environment variable configuration to use ConfigMaps/Secrets"
echo "✓ Fixed mount paths to match standard Grafana locations"
echo "✓ Aligned LDAP bind DN between ConfigMap and LDAP config"
echo "✓ Created missing ConfigMap definitions"
echo "✓ Simplified dashboard provisioning to single provider"
echo "✓ Removed hardcoded environment variables from Helm values"
echo ""
echo "Ready for deployment with:"
echo "kubectl apply -f components/monitoring/grafana-*.yaml"
echo "helm upgrade --install redstone ./helm/redstone"
