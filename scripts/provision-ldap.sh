#!/bin/bash
# Direct LDAP provisioning script that uses curl to interact with LLDAP API
# This simplifies the provisioning process by using direct API calls we've verified work

# Don't exit on errors, as we want to try all steps
set +e

echo "🔐 LLDAP Direct Provisioning Script"

# Debug mode - set to true to enable verbose output
DEBUG=true

# Constants
LDAP_API_URL="http://localhost:3892"
LDAP_ADMIN="admin"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminadmin}"

# Emojis for better UX
SUCCESS="✅"
FAILURE="❌"
INFO="ℹ️"
WARNING="⚠️"

# Debug function
debug() {
  if [ "$DEBUG" = true ]; then
    echo "$WARNING DEBUG: $1"
  fi
}

# Function to get JWT token
get_auth_token() {
  echo "🔑 Getting authentication token..."
  
  TOKEN_RESPONSE=$(curl -s -X POST "$LDAP_API_URL/auth/simple/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$LDAP_ADMIN\", \"password\":\"$LDAP_ADMIN_PASSWORD\"}")
  
  # Extract the token from the response
  if echo "$TOKEN_RESPONSE" | grep -q "token"; then
    JWT_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"\(.*\)"/\1/')
    echo "$SUCCESS Got token: ${JWT_TOKEN:0:20}..."
    return 0
  else
    echo "$FAILURE Failed to get token"
    debug "Full response: $TOKEN_RESPONSE"
    exit 1
  fi
}

# Function to create a user
create_user() {
  local token=$1
  local username=$2
  local display_name=$3
  local email=$4
  local password=$5
  
  echo "👤 Creating user $username..."
  
  debug "Checking if user exists: $username"
  # First check if user exists using correct API endpoint
  USER_LIST_RESPONSE=$(curl -s -X GET "$LDAP_API_URL/api/user/list" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" 2>&1)
  
  debug "User list response: $USER_LIST_RESPONSE"
  
  if echo "$USER_LIST_RESPONSE" | grep -q "\"username\":\"$username\""; then
    echo "$INFO User $username already exists"
    return 0
  fi
  
  # Create the user with careful JSON formatting
  debug "Creating user with username: $username, display_name: $display_name"
  CREATE_RESPONSE=$(curl -v -X POST "$LDAP_API_URL/api/user/create" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$username\",\"email\":\"$email\",\"display_name\":\"$display_name\",\"first_name\":\"\",\"last_name\":\"\",\"password\":\"$password\",\"password_confirmation\":\"$password\"}" 2>&1)
  
  # Check if response indicates success
  if echo "$CREATE_RESPONSE" | grep -q "id"; then
    echo "$SUCCESS Created user $username"
  else
    echo "$FAILURE Failed to create user $username"
    debug "Full create response: $CREATE_RESPONSE"
  fi
}

# Function to create a group
create_group() {
  local token=$1
  local group_name=$2
  local description=$3
  
  echo "👥 Creating group $group_name..."
  
  # First check if group exists using correct API endpoint
  debug "Checking if group exists: $group_name"
  GROUP_LIST_RESPONSE=$(curl -s -X GET "$LDAP_API_URL/api/group/list" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" 2>&1)
  
  debug "Group list response: ${GROUP_LIST_RESPONSE:0:200}..."
  
  if echo "$GROUP_LIST_RESPONSE" | grep -q "\"display_name\":\"$group_name\""; then
    echo "$INFO Group $group_name already exists"
    return 0
  fi
  
  # Create the group with careful JSON formatting
  debug "Creating group with name: $group_name"
  CREATE_RESPONSE=$(curl -v -X POST "$LDAP_API_URL/api/group/create" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"display_name\":\"$group_name\",\"description\":\"$description\"}" 2>&1)
  
  # Check if response indicates success
  if echo "$CREATE_RESPONSE" | grep -q "id"; then
    echo "$SUCCESS Created group $group_name"
  else
    echo "$FAILURE Failed to create group $group_name"
    debug "Full create response: $CREATE_RESPONSE"
  fi
}

# Function to add user to group
add_user_to_group() {
  local token=$1
  local username=$2
  local group_name=$3
  
  echo "🔄 Adding user $username to group $group_name..."
  
  # Get group id first
  debug "Getting group list to find ID for: $group_name"
  GROUP_INFO=$(curl -s -X GET "$LDAP_API_URL/api/group/list" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" 2>&1)
  
  debug "Group info response: ${GROUP_INFO:0:200}..."
  
  # Extract the group ID using jq if available, otherwise use grep
  if command -v jq > /dev/null; then
    GROUP_ID=$(echo "$GROUP_INFO" | jq -r ".groups[] | select(.display_name == \"$group_name\") | .id" 2>/dev/null)
  else
    # Fallback to grep/sed approach
    GROUP_ID=$(echo "$GROUP_INFO" | grep -o "\"display_name\":\"$group_name\".*\"id\":\"[^\"]*\"" | sed 's/.*"id":"\([^"]*\)".*/\1/')
  fi
  
  if [ -z "$GROUP_ID" ]; then
    echo "$FAILURE Could not find group $group_name"
    debug "Available groups: $(echo "$GROUP_INFO" | grep -o '"display_name":"[^"]*"')"
    return 1
  fi
  
  debug "Found group ID for $group_name: $GROUP_ID"
  
  # Add user to group with careful JSON formatting
  ADD_RESPONSE=$(curl -v -X POST "$LDAP_API_URL/api/group/add_member" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"group_id\":\"$GROUP_ID\",\"username\":\"$username\"}" 2>&1)
  
  # Check response
  if echo "$ADD_RESPONSE" | grep -q "200 OK"; then
    echo "$SUCCESS Added user $username to group $group_name"
  else
    echo "$FAILURE Failed to add user to group"
    debug "Full add response: $ADD_RESPONSE"
  fi
}

# Function to verify LDAP API access
verify_api_access() {
  local token=$1
  
  echo "🔍 Verifying LLDAP API access..."
  
  # Check server version as a simple API test
  VERSION_RESPONSE=$(curl -s -X GET "$LDAP_API_URL/api/server/version" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" 2>&1)
  
  if echo "$VERSION_RESPONSE" | grep -q "version"; then
    VERSION=$(echo "$VERSION_RESPONSE" | grep -o '"version":"[^"]*"' | cut -d '"' -f 4)
    echo "$SUCCESS LLDAP API access verified - version: $VERSION"
    return 0
  else
    echo "$FAILURE LLDAP API access failed"
    debug "Full version response: $VERSION_RESPONSE"
    return 1
  fi
}

# Main function
main() {
  echo "🚀 Starting LDAP provisioning"
  
  # Check if LDAP server is accessible
  if ! curl -s --connect-timeout 5 "$LDAP_API_URL" > /dev/null; then
    echo "$FAILURE Cannot connect to LDAP server at $LDAP_API_URL"
    echo "$INFO Please check if the LDAP service is running and ports are correctly mapped"
    exit 1
  fi
  
  # Get authentication token - sets the JWT_TOKEN global variable
  get_auth_token
  
  # Verify API access before proceeding
  verify_api_access "$JWT_TOKEN" || echo "$WARNING Proceeding despite API verification failure"
  
  # Create users
  create_user "$JWT_TOKEN" "admin_user" "Admin User" "admin@redstone.local" "adminpass"
  create_user "$JWT_TOKEN" "developer_user" "Developer User" "developer@redstone.local" "developerpass"
  create_user "$JWT_TOKEN" "viewer_user" "Viewer User" "viewer@redstone.local" "viewerpass"
  
  # Create groups
  create_group "$JWT_TOKEN" "admins" "Administrator group"
  create_group "$JWT_TOKEN" "developers" "Developer group"
  create_group "$JWT_TOKEN" "viewers" "Viewer group"
  create_group "$JWT_TOKEN" "redmine_users" "Redmine users group"
  create_group "$JWT_TOKEN" "redmine_admins" "Redmine administrators group"
  create_group "$JWT_TOKEN" "grafana_users" "Grafana users group"
  create_group "$JWT_TOKEN" "grafana_editors" "Grafana editors group"
  create_group "$JWT_TOKEN" "grafana_admins" "Grafana administrators group"
  
  # Wait a moment for groups to be created
  echo "$INFO Waiting for groups to propagate..."
  sleep 2
  
  # Add users to groups
  add_user_to_group "$JWT_TOKEN" "admin_user" "admins"
  add_user_to_group "$JWT_TOKEN" "admin_user" "redmine_admins"
  add_user_to_group "$JWT_TOKEN" "admin_user" "grafana_admins"
  
  add_user_to_group "$JWT_TOKEN" "developer_user" "developers"
  add_user_to_group "$JWT_TOKEN" "developer_user" "redmine_users"
  add_user_to_group "$JWT_TOKEN" "developer_user" "grafana_editors"
  
  add_user_to_group "$JWT_TOKEN" "viewer_user" "viewers"
  add_user_to_group "$JWT_TOKEN" "viewer_user" "redmine_users"
  add_user_to_group "$JWT_TOKEN" "viewer_user" "grafana_users"
  
  echo "$SUCCESS LDAP provisioning completed successfully!"
}

# Execute main function
main
