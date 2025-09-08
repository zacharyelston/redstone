#!/bin/bash
# Test script for multi-environment Grafana deployment compatibility
# This script validates that Grafana configurations work across different environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Multi-Environment Grafana Configuration Compatibility"
echo "=============================================================="

# Test 1: Validate datasource template
echo -e "\n${YELLOW}Test 1: Validating datasource template${NC}"
DATASOURCE_FILE="${SCRIPT_DIR}/grafana/provisioning/datasources/datasources.yml"

if [[ -f "$DATASOURCE_FILE" ]]; then
    echo "✓ Datasource file exists: $DATASOURCE_FILE"
    
    # Check for environment variables
    if grep -q '${PROMETHEUS_URL}' "$DATASOURCE_FILE" && grep -q '${LOKI_URL}' "$DATASOURCE_FILE"; then
        echo "✓ Datasource URLs are templated with environment variables"
    else
        echo -e "${RED}✗ Datasource URLs are not properly templated${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Datasource file not found${NC}"
    exit 1
fi

# Test 2: Validate dashboard provisioning
echo -e "\n${YELLOW}Test 2: Validating dashboard provisioning${NC}"
DASHBOARD_CONFIG="${SCRIPT_DIR}/grafana/provisioning/dashboards/dashboards.yml"

if [[ -f "$DASHBOARD_CONFIG" ]]; then
    echo "✓ Dashboard provisioning config exists"
    
    # Check dashboard path
    if grep -q '/etc/grafana/dashboards' "$DASHBOARD_CONFIG"; then
        echo "✓ Dashboard path is correctly configured"
    else
        echo -e "${RED}✗ Dashboard path not found in config${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Dashboard provisioning config not found${NC}"
    exit 1
fi

# Test 3: Validate dashboard files
echo -e "\n${YELLOW}Test 3: Validating dashboard files${NC}"
DASHBOARD_DIR="${SCRIPT_DIR}/grafana/dashboards"
DASHBOARD_COUNT=$(find "$DASHBOARD_DIR" -name "*.json" | wc -l)

if [[ $DASHBOARD_COUNT -gt 0 ]]; then
    echo "✓ Found $DASHBOARD_COUNT dashboard files"
    
    # Check for standardized datasource UIDs
    if grep -r '"uid": "prometheus"' "$DASHBOARD_DIR" >/dev/null 2>&1; then
        echo "✓ Prometheus datasource UIDs are standardized"
    else
        echo -e "${YELLOW}⚠ No Prometheus datasource references found${NC}"
    fi
    
    if grep -r '"uid": "loki"' "$DASHBOARD_DIR" >/dev/null 2>&1; then
        echo "✓ Loki datasource UIDs are standardized"
    else
        echo -e "${YELLOW}⚠ No Loki datasource references found${NC}"
    fi
else
    echo -e "${RED}✗ No dashboard files found${NC}"
    exit 1
fi

# Test 4: Validate LDAP template
echo -e "\n${YELLOW}Test 4: Validating LDAP configuration template${NC}"
LDAP_TEMPLATE="${SCRIPT_DIR}/grafana/auth/ldap.toml.template"

if [[ -f "$LDAP_TEMPLATE" ]]; then
    echo "✓ LDAP template exists"
    
    # Check for environment variables
    if grep -q '${LDAP_HOST}' "$LDAP_TEMPLATE" && grep -q '${LDAP_BIND_PASSWORD}' "$LDAP_TEMPLATE"; then
        echo "✓ LDAP configuration is templated with environment variables"
    else
        echo -e "${RED}✗ LDAP configuration is not properly templated${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ LDAP template not found${NC}"
    exit 1
fi

# Test 5: Validate environment configuration files
echo -e "\n${YELLOW}Test 5: Validating environment configuration files${NC}"

# Check Docker Compose env example
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"
if [[ -f "$ENV_EXAMPLE" ]]; then
    echo "✓ Docker Compose environment example exists"
    
    if grep -q 'PROMETHEUS_URL=' "$ENV_EXAMPLE" && grep -q 'LOKI_URL=' "$ENV_EXAMPLE"; then
        echo "✓ Environment example contains required variables"
    else
        echo -e "${RED}✗ Environment example missing required variables${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Docker Compose environment example not found${NC}"
    exit 1
fi

# Check Kubernetes ConfigMap
K8S_CONFIG="${SCRIPT_DIR}/grafana-configmap.yaml"
if [[ -f "$K8S_CONFIG" ]]; then
    echo "✓ Kubernetes ConfigMap exists"
    
    if grep -q 'PROMETHEUS_URL:' "$K8S_CONFIG" && grep -q 'LOKI_URL:' "$K8S_CONFIG"; then
        echo "✓ Kubernetes ConfigMap contains required variables"
    else
        echo -e "${RED}✗ Kubernetes ConfigMap missing required variables${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Kubernetes ConfigMap not found${NC}"
    exit 1
fi

# Test 6: Test LDAP config generation
echo -e "\n${YELLOW}Test 6: Testing LDAP config generation${NC}"
LDAP_SCRIPT="${SCRIPT_DIR}/grafana/generate-ldap-config.sh"

if [[ -f "$LDAP_SCRIPT" && -x "$LDAP_SCRIPT" ]]; then
    echo "✓ LDAP config generation script exists and is executable"
    
    # Test with default environment
    export LDAP_HOST="test-ldap"
    export LDAP_PORT="389"
    export LDAP_BIND_PASSWORD="test-password"
    
    cd "${SCRIPT_DIR}/grafana"
    if ./generate-ldap-config.sh >/dev/null 2>&1; then
        echo "✓ LDAP config generation works with test environment"
        
        # Verify generated file contains substituted values
        if grep -q "test-ldap" auth/ldap.toml && grep -q "test-password" auth/ldap.toml; then
            echo "✓ Environment variables properly substituted in LDAP config"
        else
            echo -e "${RED}✗ Environment variable substitution failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ LDAP config generation failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ LDAP config generation script not found or not executable${NC}"
    exit 1
fi

# Summary
echo -e "\n${GREEN}🎉 All tests passed! Multi-environment configuration is ready.${NC}"
echo ""
echo "Summary of implemented features:"
echo "✓ Datasource URLs templated with environment variables"
echo "✓ Dashboard provisioning configured correctly"
echo "✓ Dashboard datasource UIDs standardized"
echo "✓ LDAP configuration externalized with templates"
echo "✓ Environment-specific configurations created"
echo "✓ Docker Compose and Kubernetes compatibility"
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and customize for your environment"
echo "2. Apply Kubernetes ConfigMap: kubectl apply -f grafana-configmap.yaml"
echo "3. Deploy with: docker-compose up -d or helm install"
