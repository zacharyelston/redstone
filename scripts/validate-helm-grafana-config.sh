#!/bin/bash

# Helm Grafana Configuration Validation Script
# Validates that our Helm templates will generate the correct ConfigMaps for Grafana provisioning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Helm Grafana Configuration Validation ===${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "helm/redstone/Chart.yaml" ]; then
    echo -e "${RED}✗ Please run this script from the redstone project root${NC}"
    exit 1
fi

cd helm/redstone

# Test 1: Validate Helm chart syntax
echo -e "${YELLOW}Test 1: Helm Chart Syntax Validation${NC}"
if helm lint . > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Helm chart syntax is valid${NC}"
else
    echo -e "${RED}✗ Helm chart has syntax errors:${NC}"
    helm lint .
    exit 1
fi

# Test 2: Check if required templates exist
echo -e "${YELLOW}Test 2: Required Template Files${NC}"
required_templates=(
    "templates/grafana-datasources.yaml"
    "templates/grafana-dashboards-simple.yaml"
    "templates/grafana-dashboard-metrics.yaml"
    "templates/grafana-dashboard-working.yaml"
)

for template in "${required_templates[@]}"; do
    if [ -f "$template" ]; then
        echo -e "${GREEN}✓ Found: $template${NC}"
    else
        echo -e "${RED}✗ Missing: $template${NC}"
    fi
done

# Test 3: Dry-run Helm template generation
echo -e "${YELLOW}Test 3: Helm Template Generation${NC}"
echo "Generating templates with dry-run..."

if helm template redstone . --dry-run > /tmp/helm-output.yaml 2>/dev/null; then
    echo -e "${GREEN}✓ Helm templates generated successfully${NC}"
else
    echo -e "${RED}✗ Helm template generation failed:${NC}"
    helm template redstone . --dry-run
    exit 1
fi

# Test 4: Check for Grafana ConfigMaps in generated output
echo -e "${YELLOW}Test 4: Grafana ConfigMap Generation${NC}"
expected_configmaps=(
    "redstone-grafana-datasources"
    "redstone-grafana-dashboards"
    "redstone-grafana-dashboard-metrics"
    "redstone-grafana-dashboard-working"
)

for configmap in "${expected_configmaps[@]}"; do
    if grep -q "name: $configmap" /tmp/helm-output.yaml; then
        echo -e "${GREEN}✓ ConfigMap generated: $configmap${NC}"
    else
        echo -e "${RED}✗ ConfigMap missing: $configmap${NC}"
    fi
done

# Test 5: Validate datasource ConfigMap content
echo -e "${YELLOW}Test 5: Datasource ConfigMap Content${NC}"
if grep -A 20 "name: redstone-grafana-datasources" /tmp/helm-output.yaml | grep -q "datasources.yaml"; then
    echo -e "${GREEN}✓ Datasource ConfigMap has datasources.yaml key${NC}"
    
    # Check for expected datasources
    if grep -A 50 "datasources.yaml" /tmp/helm-output.yaml | grep -q "name: Loki"; then
        echo -e "${GREEN}✓ Loki datasource found in ConfigMap${NC}"
    else
        echo -e "${RED}✗ Loki datasource missing from ConfigMap${NC}"
    fi
    
    if grep -A 50 "datasources.yaml" /tmp/helm-output.yaml | grep -q "name: Prometheus"; then
        echo -e "${GREEN}✓ Prometheus datasource found in ConfigMap${NC}"
    else
        echo -e "${RED}✗ Prometheus datasource missing from ConfigMap${NC}"
    fi
else
    echo -e "${RED}✗ Datasource ConfigMap missing datasources.yaml key${NC}"
fi

# Test 6: Check Grafana values configuration
echo -e "${YELLOW}Test 6: Grafana Values Configuration${NC}"
if grep -q "datasourcesConfigMaps:" values.yaml; then
    echo -e "${GREEN}✓ datasourcesConfigMaps configured in values.yaml${NC}"
    
    # Check if the ConfigMap reference is correct
    if grep -A 5 "datasourcesConfigMaps:" values.yaml | grep -q "redstone-grafana-datasources"; then
        echo -e "${GREEN}✓ Correct datasource ConfigMap reference${NC}"
    else
        echo -e "${RED}✗ Incorrect datasource ConfigMap reference${NC}"
    fi
else
    echo -e "${RED}✗ datasourcesConfigMaps not configured in values.yaml${NC}"
fi

if grep -q "dashboardsConfigMaps:" values.yaml; then
    echo -e "${GREEN}✓ dashboardsConfigMaps configured in values.yaml${NC}"
else
    echo -e "${RED}✗ dashboardsConfigMaps not configured in values.yaml${NC}"
fi

# Test 7: Check dashboard provider configuration
echo -e "${YELLOW}Test 7: Dashboard Provider Configuration${NC}"
if grep -A 20 "dashboardProviders:" values.yaml | grep -q "redstone-dashboards"; then
    echo -e "${GREEN}✓ Dashboard providers configured${NC}"
else
    echo -e "${RED}✗ Dashboard providers not properly configured${NC}"
fi

# Test 8: Extract and validate generated ConfigMaps
echo -e "${YELLOW}Test 8: Extract Generated ConfigMaps for Inspection${NC}"
mkdir -p /tmp/grafana-configmaps

# Extract each ConfigMap
for configmap in "${expected_configmaps[@]}"; do
    if grep -A 1000 "name: $configmap" /tmp/helm-output.yaml | sed '/^---$/q' > "/tmp/grafana-configmaps/$configmap.yaml"; then
        echo -e "${GREEN}✓ Extracted: $configmap.yaml${NC}"
        
        # Show size and key count
        size=$(wc -c < "/tmp/grafana-configmaps/$configmap.yaml")
        keys=$(grep -c "^  [a-zA-Z]" "/tmp/grafana-configmaps/$configmap.yaml" || echo "0")
        echo "    Size: ${size} bytes, Keys: ${keys}"
    else
        echo -e "${RED}✗ Failed to extract: $configmap${NC}"
    fi
done

# Test 9: Validate Grafana chart dependencies
echo -e "${YELLOW}Test 9: Grafana Chart Dependencies${NC}"
if [ -f "Chart.lock" ]; then
    echo -e "${GREEN}✓ Chart.lock exists${NC}"
    
    if grep -q "grafana" Chart.lock; then
        grafana_version=$(grep -A 2 "name: grafana" Chart.lock | grep "version:" | awk '{print $2}')
        echo -e "${GREEN}✓ Grafana chart dependency: $grafana_version${NC}"
    else
        echo -e "${RED}✗ Grafana dependency not found in Chart.lock${NC}"
    fi
else
    echo -e "${YELLOW}! Chart.lock missing - run 'helm dependency update'${NC}"
fi

# Summary and next steps
echo ""
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo "Generated files available in /tmp/grafana-configmaps/ for inspection"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Run the test script against your Release.com deployment:"
echo "   GRAFANA_URL=https://grafana-redstone-e601c-ted11d4.rls.sh ./scripts/test-grafana-provisioning.sh"
echo ""
echo "2. If ConfigMaps are missing, check Release.com deployment logs"
echo ""
echo "3. If ConfigMaps exist but Grafana doesn't see them, check Grafana pod logs"
echo ""
echo "4. Compare generated ConfigMaps with what's actually deployed in Kubernetes"

# Cleanup
rm -f /tmp/helm-output.yaml

echo ""
echo -e "${BLUE}Validation completed at $(date)${NC}"
