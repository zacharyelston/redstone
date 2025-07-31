#!/bin/bash
# Test LDAP authentication for Redmine and Grafana
# This script tests if a developer user can access Redmine and Grafana

set -e

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

echo -e "${YELLOW}🧪 Testing LDAP authentication for Redmine and Grafana${NC}"

# Test user credentials
TEST_USER="developer_user"
TEST_PASSWORD="developer_password"

# Test URLs
REDMINE_URL="http://localhost:3000"
GRAFANA_URL="http://localhost:3030"

echo -e "\n${YELLOW}Step 1: Checking if services are running...${NC}"

# Check if Redmine is running
if curl -s -o /dev/null -w "%{http_code}" $REDMINE_URL | grep -q "200"; then
  echo -e "${GREEN}✅ Redmine is running${NC}"
else
  echo -e "${RED}❌ Redmine is not running or not accessible at $REDMINE_URL${NC}"
  echo -e "${YELLOW}Starting Redmine...${NC}"
  docker compose up -d redmica
  echo -e "${YELLOW}Waiting for Redmine to start (30 seconds)...${NC}"
  sleep 30
fi

# Check if Grafana is running
if curl -s -o /dev/null -w "%{http_code}" $GRAFANA_URL | grep -q "200"; then
  echo -e "${GREEN}✅ Grafana is running${NC}"
else
  echo -e "${RED}❌ Grafana is not running or not accessible at $GRAFANA_URL${NC}"
  echo -e "${YELLOW}Starting Grafana...${NC}"
  docker compose up -d grafana
  echo -e "${YELLOW}Waiting for Grafana to start (20 seconds)...${NC}"
  sleep 20
fi

echo -e "\n${YELLOW}Step 2: Testing Redmine LDAP authentication...${NC}"

# Test Redmine authentication using curl
echo -e "Attempting to authenticate to Redmine as $TEST_USER..."
REDMINE_LOGIN_RESPONSE=$(curl -s -c /tmp/redmine_cookies.txt -L -X POST \
  -F "username=$TEST_USER" \
  -F "password=$TEST_PASSWORD" \
  -F "login=Login" \
  -w "%{http_code}" \
  $REDMINE_URL/login)

# Check if login was successful by looking for redirect to my/page
if curl -s -b /tmp/redmine_cookies.txt -o /dev/null -w "%{http_code}" $REDMINE_URL/my/page | grep -q "200"; then
  echo -e "${GREEN}✅ Successfully authenticated to Redmine as $TEST_USER${NC}"
  # Get user info to confirm LDAP role mapping
  USER_INFO=$(curl -s -b /tmp/redmine_cookies.txt $REDMINE_URL/my/account)
  if echo "$USER_INFO" | grep -q "Developer User"; then
    echo -e "${GREEN}✅ User profile correctly shows 'Developer User'${NC}"
  else
    echo -e "${RED}❌ User profile does not show expected name 'Developer User'${NC}"
  fi
else
  echo -e "${RED}❌ Failed to authenticate to Redmine as $TEST_USER${NC}"
  echo -e "${YELLOW}This may indicate LDAP integration is not properly configured${NC}"
fi

echo -e "\n${YELLOW}Step 3: Testing Grafana LDAP authentication...${NC}"

# Test Grafana authentication using curl
echo -e "Attempting to authenticate to Grafana as $TEST_USER..."
GRAFANA_LOGIN_RESPONSE=$(curl -s -c /tmp/grafana_cookies.txt -L -X POST \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"$TEST_USER\",\"password\":\"$TEST_PASSWORD\"}" \
  -w "%{http_code}" \
  $GRAFANA_URL/login)

# Check if login was successful by looking for successful API response
if curl -s -b /tmp/grafana_cookies.txt -o /dev/null -w "%{http_code}" $GRAFANA_URL/api/user | grep -q "200"; then
  echo -e "${GREEN}✅ Successfully authenticated to Grafana as $TEST_USER${NC}"
  # Get user info to confirm LDAP role mapping
  USER_INFO=$(curl -s -b /tmp/grafana_cookies.txt $GRAFANA_URL/api/user)
  if echo "$USER_INFO" | grep -q "editor"; then
    echo -e "${GREEN}✅ User correctly has 'editor' role in Grafana${NC}"
  else
    echo -e "${RED}❌ User does not have expected 'editor' role in Grafana${NC}"
  fi
else
  echo -e "${RED}❌ Failed to authenticate to Grafana as $TEST_USER${NC}"
  echo -e "${YELLOW}This may indicate LDAP integration is not properly configured${NC}"
fi

# Clean up cookie files
rm -f /tmp/redmine_cookies.txt /tmp/grafana_cookies.txt

echo -e "\n${YELLOW}Test Complete!${NC}"
