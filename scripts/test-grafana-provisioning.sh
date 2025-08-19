#!/bin/bash

# Grafana Dashboard and Datasource Provisioning Test Script
# Tests and validates Grafana provisioning in Release.com deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GRAFANA_URL="${GRAFANA_URL:-https://grafana-redstone-e601c-ted11d4.rls.sh}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin123}"

echo -e "${BLUE}=== Grafana Provisioning Test Script ===${NC}"
echo "Testing Grafana deployment at: $GRAFANA_URL"
echo ""

# Function to make authenticated requests to Grafana API
grafana_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" \
            -H "Content-Type: application/json" \
            -u "$GRAFANA_USER:$GRAFANA_PASS" \
            -d "$data" \
            "$GRAFANA_URL/api/$endpoint"
    else
        curl -s -X "$method" \
            -u "$GRAFANA_USER:$GRAFANA_PASS" \
            "$GRAFANA_URL/api/$endpoint"
    fi
}

# Test 1: Check Grafana API connectivity
echo -e "${YELLOW}Test 1: Grafana API Connectivity${NC}"
if health_response=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health"); then
    if [ "$health_response" = "200" ]; then
        echo -e "${GREEN}✓ Grafana API is accessible${NC}"
    else
        echo -e "${RED}✗ Grafana API returned HTTP $health_response${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Cannot reach Grafana API${NC}"
    exit 1
fi

# Test 2: Check authentication
echo -e "${YELLOW}Test 2: Authentication${NC}"
if auth_response=$(grafana_api "user" 2>/dev/null); then
    user_login=$(echo "$auth_response" | jq -r '.login // "unknown"')
    echo -e "${GREEN}✓ Authentication successful (user: $user_login)${NC}"
else
    echo -e "${RED}✗ Authentication failed${NC}"
    echo "Please check GRAFANA_USER and GRAFANA_PASS variables"
    exit 1
fi

# Test 3: List current datasources
echo -e "${YELLOW}Test 3: Current Datasources${NC}"
datasources_response=$(grafana_api "datasources")
datasource_count=$(echo "$datasources_response" | jq '. | length')

echo "Found $datasource_count datasources:"
if [ "$datasource_count" -gt 0 ]; then
    echo "$datasources_response" | jq -r '.[] | "  - \(.name) (\(.type)) - \(.url)"'
    echo -e "${GREEN}✓ Datasources are provisioned${NC}"
else
    echo -e "${RED}✗ No datasources found${NC}"
fi

# Test 4: Check for expected datasources
echo -e "${YELLOW}Test 4: Expected Datasources Validation${NC}"
expected_datasources=("Loki" "Prometheus")
missing_datasources=()

for expected in "${expected_datasources[@]}"; do
    if echo "$datasources_response" | jq -e ".[] | select(.name == \"$expected\")" > /dev/null; then
        echo -e "${GREEN}✓ Found expected datasource: $expected${NC}"
    else
        echo -e "${RED}✗ Missing expected datasource: $expected${NC}"
        missing_datasources+=("$expected")
    fi
done

# Test 5: List current dashboards
echo -e "${YELLOW}Test 5: Current Dashboards${NC}"
dashboards_response=$(grafana_api "search?type=dash-db")
dashboard_count=$(echo "$dashboards_response" | jq '. | length')

echo "Found $dashboard_count dashboards:"
if [ "$dashboard_count" -gt 0 ]; then
    echo "$dashboards_response" | jq -r '.[] | "  - \(.title) (ID: \(.id), Folder: \(.folderTitle // "General"))"'
    echo -e "${GREEN}✓ Dashboards are provisioned${NC}"
else
    echo -e "${RED}✗ No dashboards found${NC}"
fi

# Test 6: Check for expected dashboards
echo -e "${YELLOW}Test 6: Expected Dashboards Validation${NC}"
expected_dashboards=("System Overview" "Service Metrics" "Working Metrics" "Logs Explorer")
missing_dashboards=()

for expected in "${expected_dashboards[@]}"; do
    if echo "$dashboards_response" | jq -e ".[] | select(.title | contains(\"$expected\"))" > /dev/null; then
        echo -e "${GREEN}✓ Found expected dashboard: $expected${NC}"
    else
        echo -e "${RED}✗ Missing expected dashboard: $expected${NC}"
        missing_dashboards+=("$expected")
    fi
done

# Test 7: Check Redstone folder
echo -e "${YELLOW}Test 7: Redstone Folder Validation${NC}"
folders_response=$(grafana_api "folders")
if echo "$folders_response" | jq -e '.[] | select(.title == "Redstone")' > /dev/null; then
    echo -e "${GREEN}✓ Redstone folder exists${NC}"
    
    # Get dashboards in Redstone folder
    redstone_folder_id=$(echo "$folders_response" | jq -r '.[] | select(.title == "Redstone") | .id')
    redstone_dashboards=$(grafana_api "search?folderIds=$redstone_folder_id&type=dash-db")
    redstone_dashboard_count=$(echo "$redstone_dashboards" | jq '. | length')
    echo "  - Contains $redstone_dashboard_count dashboards"
else
    echo -e "${RED}✗ Redstone folder not found${NC}"
fi

# Test 8: Test datasource connectivity
echo -e "${YELLOW}Test 8: Datasource Connectivity${NC}"
if [ "$datasource_count" -gt 0 ]; then
    echo "$datasources_response" | jq -r '.[] | .id' | while read -r ds_id; do
        ds_name=$(echo "$datasources_response" | jq -r ".[] | select(.id == $ds_id) | .name")
        echo "Testing connectivity for: $ds_name"
        
        # Test datasource proxy
        if proxy_response=$(grafana_api "datasources/proxy/$ds_id/api/v1/label/__name__/values" 2>/dev/null); then
            echo -e "${GREEN}  ✓ $ds_name connectivity OK${NC}"
        else
            echo -e "${RED}  ✗ $ds_name connectivity failed${NC}"
        fi
    done
else
    echo -e "${YELLOW}  Skipping - no datasources to test${NC}"
fi

# Summary and Recommendations
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"

if [ ${#missing_datasources[@]} -eq 0 ] && [ ${#missing_dashboards[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Grafana provisioning is working correctly.${NC}"
else
    echo -e "${RED}✗ Issues found with Grafana provisioning:${NC}"
    
    if [ ${#missing_datasources[@]} -gt 0 ]; then
        echo -e "${RED}Missing datasources:${NC}"
        printf '  - %s\n' "${missing_datasources[@]}"
    fi
    
    if [ ${#missing_dashboards[@]} -gt 0 ]; then
        echo -e "${RED}Missing dashboards:${NC}"
        printf '  - %s\n' "${missing_dashboards[@]}"
    fi
    
    echo ""
    echo -e "${YELLOW}Recommended Actions:${NC}"
    echo "1. Check if ConfigMaps are created in the namespace:"
    echo "   kubectl get configmap | grep grafana"
    echo ""
    echo "2. Check Grafana pod logs for provisioning errors:"
    echo "   kubectl logs deployment/redstone-grafana"
    echo ""
    echo "3. Verify ConfigMap content:"
    echo "   kubectl describe configmap redstone-grafana-datasources"
    echo "   kubectl describe configmap redstone-grafana-dashboards"
    echo ""
    echo "4. Check Grafana provisioning configuration:"
    echo "   kubectl exec deployment/redstone-grafana -- ls -la /etc/grafana/provisioning/"
    echo ""
    echo "5. Restart Grafana to reload provisioning:"
    echo "   kubectl rollout restart deployment/redstone-grafana"
fi

echo ""
echo -e "${BLUE}Test completed at $(date)${NC}"
