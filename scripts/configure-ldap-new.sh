#!/bin/bash
# LDAP Configuration Script
# This script configures the LDAP service for Redstone using the official LLDAP bootstrap approach
# Following "Built for Clarity" design philosophy - preferring standardized, simple approaches

set -e

# Constants and directory setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
LDAP_DIR="$PROJECT_ROOT/components/ldap"
BOOTSTRAP_DIR="$LDAP_DIR/bootstrap"

# Default admin password if not set
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminadmin}"

# Visual elements for better UX
SUCCESS="✅"
FAILURE="❌"
INFO="ℹ️"
WARNING="⚠️"

echo "🔐 Starting LDAP configuration using official LLDAP bootstrap approach"

# Source common utilities if they exist
if [ -f "$SCRIPT_DIR/common.sh" ]; then
  source "$SCRIPT_DIR/common.sh"
fi

# Check if custom LDAP config exists
CUSTOM_CONFIG="${PROJECT_ROOT}/custom/ldap-config.yaml"
DEFAULT_CONFIG="${LDAP_DIR}/ldap-defaults.yaml"
TARGET_CONFIG="${LDAP_DIR}/config/ldap.yaml"

# Create config directory if it doesn't exist
mkdir -p "${LDAP_DIR}/config"

if [ -f "$CUSTOM_CONFIG" ]; then
    echo "$INFO Found custom LDAP configuration, using: $CUSTOM_CONFIG"
    # Copy the custom config to the target location
    cp "$CUSTOM_CONFIG" "$TARGET_CONFIG"
else
    echo "$INFO Using default LDAP configuration: $DEFAULT_CONFIG"
    # Copy the default config to the target location
    cp "$DEFAULT_CONFIG" "$TARGET_CONFIG"
fi

# Step 1: Check if the LDAP container exists and is running
echo "$INFO Checking LDAP container status..."

# Find the LDAP container (either lldap or ldap naming)
LDAP_CONTAINER=$(docker ps --filter name=ldap --format "{{.Names}}" | grep -E 'ldap|lldap' | head -n 1)

if [ -z "$LDAP_CONTAINER" ]; then
  echo "$FAILURE No running LDAP container found."
  echo "$INFO Starting LDAP service from docker-compose..."
  docker compose up -d ldap
  
  # Wait for container to start
  echo "$INFO Waiting for LDAP container to start..."
  sleep 5
  
  # Check again for the container
  LDAP_CONTAINER=$(docker ps --filter name=ldap --format "{{.Names}}" | grep -E 'ldap|lldap' | head -n 1)
  
  if [ -z "$LDAP_CONTAINER" ]; then
    echo "$FAILURE Failed to start LDAP container."
    exit 1
  fi
fi

echo "$SUCCESS Using LDAP container: $LDAP_CONTAINER"

# Check container health if possible
CONTAINER_HEALTH=$(docker inspect --format="{{.State.Health.Status}}" "$LDAP_CONTAINER" 2>/dev/null || echo "health_unknown")
if [ "$CONTAINER_HEALTH" = "health_unknown" ]; then
  echo "$INFO Container health check not available, checking if container is running..."
  CONTAINER_STATUS=$(docker inspect --format="{{.State.Status}}" "$LDAP_CONTAINER")
  if [ "$CONTAINER_STATUS" != "running" ]; then
    echo "$FAILURE LDAP container is not running (status: $CONTAINER_STATUS)."
    exit 1
  fi
elif [ "$CONTAINER_HEALTH" != "healthy" ]; then
  echo "$WARNING LDAP container is not healthy (status: $CONTAINER_HEALTH). Proceeding anyway."
else
  echo "$SUCCESS LDAP container is healthy."
fi

# Show port mappings for debugging
echo "$INFO LDAP container port mappings:"
docker port $LDAP_CONTAINER

# LLDAP web UI/API port is mapped to 3892 on the host in docker-compose
LLDAP_PORT=3892
LLDAP_API_URL="http://localhost:$LLDAP_PORT"
echo "$INFO LLDAP API URL: $LLDAP_API_URL"

# Set the admin password for bootstrap
export LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminadmin}"

# Execute the bootstrap using direct API calls for simplicity and reliability
echo "🔄 Provisioning LLDAP with users and groups..."

# Create a simpler approach following our "Built for Clarity" design philosophy
echo "$INFO Using direct API provisioning approach..."

# Copy configuration files to a temp directory
TMP_DIR=$(mktemp -d)

# Function to create users via API - Using jq for proper JSON parsing
provision_users() {
  echo "$INFO Authenticating with LLDAP API..."
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "$FAILURE jq is required but not installed. Please install jq for JSON parsing."
    return 1
  fi
  
  # Helper function to create a group
  create_group() {
    local GROUP_NAME="$1"
    
    echo "$INFO Creating group: $GROUP_NAME"
    
    # Create group via API with debugging
    GROUP_RESPONSE=$(curl -s -v -X POST "$LLDAP_API_URL/api/group/create" \
      -H "Authorization: Bearer $JWT_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"display_name":"'"$GROUP_NAME"'","name":"'"$GROUP_NAME"'"}' 2>&1)
    
    # Check for successful response
    if echo "$GROUP_RESPONSE" | grep -q "HTTP/1.1 200"; then
      echo "$SUCCESS Group created successfully: $GROUP_NAME"
    else
      echo "$WARNING Group creation may have failed. Response excerpt:"
      echo "$GROUP_RESPONSE" | grep -E "(HTTP|error|fail|warning)" || echo "No error details available"
    fi
  }
  
  # Helper function to create a user
  create_user() {
    local USERNAME="$1"
    local EMAIL="$2"
    local FIRST_NAME="$3"
    local LAST_NAME="$4"
    local PASSWORD="$5"
    
    echo "$INFO Creating user: $USERNAME (Email: $EMAIL)"
    
    # Create user via API with debugging
    USER_RESPONSE=$(curl -s -v -X POST "$LLDAP_API_URL/api/user/create" \
      -H "Authorization: Bearer $JWT_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "id":"'"$USERNAME"'",
        "email":"'"$EMAIL"'",
        "display_name":"'"$FIRST_NAME $LAST_NAME"'",
        "first_name":"'"$FIRST_NAME"'",
        "last_name":"'"$LAST_NAME"'"
      }' 2>&1)
    
    # Check response
    if echo "$USER_RESPONSE" | grep -q "HTTP/1.1 200"; then
      echo "$SUCCESS User created: $USERNAME"
      return 0
    else
      echo "$WARNING User creation may have failed. Response excerpt:"
      echo "$USER_RESPONSE" | grep -E "(HTTP|error|fail|warning)" || echo "No error details available"
      return 1
    fi
  }
  
  # Get authentication token
  TOKEN_RESPONSE=$(curl -s -X POST "$LLDAP_API_URL/auth/simple/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"'"$LDAP_ADMIN_PASSWORD"'"}' || echo "ERROR")
  
  if [[ "$TOKEN_RESPONSE" == "ERROR" ]]; then
    echo "$FAILURE Failed to connect to LLDAP API. Check if container is running and port 3892 is accessible."
    return 1
  fi
  
  # Extract token using jq
  if ! JWT_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token' 2>/dev/null); then
    echo "$FAILURE Failed to extract JWT token. Response was: ${TOKEN_RESPONSE:0:100}..."
    return 1
  elif [[ "$JWT_TOKEN" == "null" || -z "$JWT_TOKEN" ]]; then
    echo "$FAILURE Failed to extract JWT token. Response was: ${TOKEN_RESPONSE:0:100}..."
    return 1
  else
    echo "$SUCCESS Successfully authenticated with LLDAP API"
  fi
  
  # Process groups first
  echo "$INFO Creating groups..."
  for GROUP_FILE in "$BOOTSTRAP_DIR"/group-configs/*.json; do
    if [ -f "$GROUP_FILE" ]; then
      echo "$INFO Processing group file: $(basename "$GROUP_FILE")"
      
      # Handle both array and single object formats using jq
      if jq -e 'if type == "array" then true else false end' "$GROUP_FILE" > /dev/null 2>&1; then
        # It's an array of groups
        for GROUP_NAME in $(jq -r '.[] | .name' "$GROUP_FILE"); do
          if [ ! -z "$GROUP_NAME" ] && [ "$GROUP_NAME" != "null" ]; then
            create_group "$GROUP_NAME"
          fi
        done
      else
        # It's a single group object
        GROUP_NAME=$(jq -r '.name' "$GROUP_FILE")
        if [ ! -z "$GROUP_NAME" ] && [ "$GROUP_NAME" != "null" ]; then
          create_group "$GROUP_NAME"
        else
          echo "$WARNING No group name found in file: $(basename "$GROUP_FILE")"
        fi
      fi
    fi
  done
  
  # Small delay to ensure groups are created
  echo "$INFO Waiting for groups to be processed..."
  sleep 2
  
  # Process users
  echo "$INFO Creating users and assigning to groups..."
  for USER_FILE in "$BOOTSTRAP_DIR"/user-configs/*.json; do
    if [ -f "$USER_FILE" ]; then
      echo "$INFO Processing user file: $(basename "$USER_FILE")"
      
      # Extract user fields using jq
      USER_ID=$(jq -r '.id' "$USER_FILE")
      EMAIL=$(jq -r '.email' "$USER_FILE")
      PASSWORD=$(jq -r 'if has("password") then .password else "" end' "$USER_FILE")
      DISPLAY_NAME=$(jq -r 'if has("displayName") then .displayName else .id end' "$USER_FILE")
      FIRST_NAME=$(jq -r 'if has("firstName") then .firstName else "" end' "$USER_FILE")
      LAST_NAME=$(jq -r 'if has("lastName") then .lastName else "" end' "$USER_FILE")
      
      # Validate required fields
      if [[ "$USER_ID" == "null" || -z "$USER_ID" || "$EMAIL" == "null" || -z "$EMAIL" ]]; then
        echo "$WARNING Missing required fields (id and email) in user file: $(basename "$USER_FILE")"
        continue
      fi
      
      # Use our helper function to create user with better debugging
      if create_user "$USER_ID" "$EMAIL" "$FIRST_NAME" "$LAST_NAME" "$PASSWORD"; then
        # User created successfully, continue with group assignments
        USER_CREATED=true
      else
        echo "$WARNING User creation may have issues, but continuing with further operations"
        USER_CREATED=false
      fi
      
      # Add user to groups if specified
      if jq -e 'has("groups")' "$USER_FILE" > /dev/null 2>&1; then
        for GROUP in $(jq -r '.groups[]' "$USER_FILE"); do
          if [ ! -z "$GROUP" ] && [ "$GROUP" != "null" ]; then
            echo "$INFO Adding $USER_ID to group: $GROUP"
            
            # Add user to group with verbose debugging
            GROUP_RESULT=$(curl -s -v -X POST "$LLDAP_API_URL/api/group/add_member" \
              -H "Authorization: Bearer $JWT_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{"group_name":"'"$GROUP"'","user_id":"'"$USER_ID"'"}' 2>&1)
            
            # Check response
            if echo "$GROUP_RESULT" | grep -q "HTTP/1.1 200"; then
              echo "$SUCCESS User $USER_ID added to group: $GROUP"
            else
              echo "$WARNING Failed to add $USER_ID to group: $GROUP - Response excerpt:"
              echo "$GROUP_RESULT" | grep -E "(HTTP|error|fail|warning)" || echo "No error details available"
            fi
          fi
        done
      fi
      
      # Set password if provided
      if [ ! -z "$PASSWORD" ] && [ "$PASSWORD" != "null" ]; then
        echo "$INFO Setting password for user: $USER_ID"
        
        # Set password with verbose debugging
        PASS_RESULT=$(curl -s -v -X POST "$LLDAP_API_URL/api/user/change_password" \
          -H "Authorization: Bearer $JWT_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"user_id":"'"$USER_ID"'","new_password":"'"$PASSWORD"'"}' 2>&1)
        
        # Check response
        if echo "$PASS_RESULT" | grep -q "HTTP/1.1 200"; then
          echo "$SUCCESS Password set for user: $USER_ID"
        else
          echo "$WARNING Failed to set password for $USER_ID - Response excerpt:"
          echo "$PASS_RESULT" | grep -E "(HTTP|error|fail|warning)" || echo "No error details available"
        fi
      fi
    fi
  done
  
  echo "$SUCCESS LLDAP users and groups provisioned successfully"
}

# Call the provisioning function
provision_users

# Perform direct LDAP validation
validate_ldap() {
  echo "$INFO Verifying LLDAP configuration..."
  echo "$INFO Performing direct LDAP query validation..."
  
  # Check if ldapsearch is installed
  if ! command -v ldapsearch &> /dev/null; then
    echo "$INFO ldap-utils not found, installing..."
    # Try to install ldap-utils using apt (Debian/Ubuntu) or brew (macOS)
    if command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y ldap-utils > /dev/null
    elif command -v brew &> /dev/null; then
      brew install openldap > /dev/null
    else
      echo "$WARNING Could not install ldap-utils. Please install manually."
      return 1
    fi
  fi
  
  # Initialize validation success flag
  VALIDATION_SUCCESS=true
  
  # Gather LDAP server information with timeout
  echo "$INFO Getting LDAP server information..."
  LDAP_INFO=$(timeout 10 ldapsearch -x -H ldap://localhost:389 -s base -b "" "(objectclass=*)" 2>&1)
  TIMEOUT_STATUS=$?
  if [ $TIMEOUT_STATUS -eq 124 ]; then
    echo "$WARNING LDAP query timed out after 10 seconds. The server may be slow or overloaded."
    VALIDATION_SUCCESS=false
  elif [ $TIMEOUT_STATUS -eq 0 ]; then
    echo "$SUCCESS LDAP server information:"
    echo "$LDAP_INFO" | grep -i "namingcontexts\|rootDSE"
  else
    echo "$FAILURE Unable to connect to LDAP server: $LDAP_INFO"
    VALIDATION_SUCCESS=false
  fi
  
  # Check what base DNs are available
  echo "$INFO Checking available LDAP base DNs..."
  BASE_DNs=$(echo "$LDAP_INFO" | grep -i namingContexts | awk '{print $2}')
  echo "$INFO Available base DNs: $BASE_DNs"
  
  # Validate users and groups structure with timeout
  echo "$INFO Validating LDAP directory structure..."
  for BASE_DN in $BASE_DNs; do
    echo "$INFO Checking structure under: $BASE_DN"
    STRUCTURE=$(timeout 5 ldapsearch -x -H ldap://localhost:389 -b "$BASE_DN" -D "uid=admin,ou=people,dc=redstone,dc=local" -w "$LDAP_ADMIN_PASSWORD" -s one "(objectClass=*)" 2>&1)
    TIMEOUT_STATUS=$?
    if [ $TIMEOUT_STATUS -eq 124 ]; then
      echo "$WARNING LDAP structure query timed out for $BASE_DN"
    elif [ $TIMEOUT_STATUS -eq 0 ]; then
      echo "$SUCCESS Found organizational units under $BASE_DN:"
      echo "$STRUCTURE" | grep -i "dn:\|ou:\|objectclass:" || echo "No organizational units found"
    else
      echo "$WARNING Error querying structure under $BASE_DN: $STRUCTURE"
    fi
  done
  
  # Perform LDAP search for users with timeout and detailed debugging
  echo "$INFO Querying LDAP users..."
  LDAP_USERS=$(timeout 5 ldapsearch -x -H ldap://localhost:389 -b "ou=people,dc=redstone,dc=local" -D "uid=admin,ou=people,dc=redstone,dc=local" -w "$LDAP_ADMIN_PASSWORD" "(objectClass=*)" 2>&1)
  TIMEOUT_STATUS=$?
  
  # Check if LDAP search was successful
  if [ $TIMEOUT_STATUS -eq 124 ]; then
    echo "$WARNING LDAP user search timed out after 5 seconds. Proceeding with limited validation."
    VALIDATION_SUCCESS=false
    LDAP_USERS=""
  elif [ $TIMEOUT_STATUS -ne 0 ]; then
    echo "$FAILURE LDAP search for users failed: $LDAP_USERS"
    VALIDATION_SUCCESS=false
    LDAP_USERS=""
  else
    echo "$SUCCESS Successfully queried LDAP users:"
    # Save all user IDs for later validation
    FOUND_USERS=$(echo "$LDAP_USERS" | grep "uid: " | awk '{print $2}')
    if [ -z "$FOUND_USERS" ]; then
      echo "$WARNING No users found in LDAP directory"
    else
      echo "$FOUND_USERS"
    fi
  fi
  
  # Perform LDAP search for groups with timeout and multiple object classes
  echo "$INFO Querying LDAP groups..."
  LDAP_GROUPS=$(timeout 5 ldapsearch -x -H ldap://localhost:389 -b "ou=groups,dc=redstone,dc=local" -D "uid=admin,ou=people,dc=redstone,dc=local" -w "$LDAP_ADMIN_PASSWORD" "(|(objectClass=groupOfUniqueNames)(objectClass=groupOfNames)(objectClass=posixGroup))" 2>&1)
  TIMEOUT_STATUS=$?
  
  # Check if LDAP search was successful
  if [ $TIMEOUT_STATUS -eq 124 ]; then
    echo "$WARNING LDAP group search timed out after 5 seconds. Proceeding with limited validation."
    VALIDATION_SUCCESS=false
    LDAP_GROUPS=""
  elif [ $TIMEOUT_STATUS -ne 0 ]; then
    echo "$FAILURE LDAP search for groups failed: $LDAP_GROUPS"
    VALIDATION_SUCCESS=false
    LDAP_GROUPS=""
  else
    echo "$SUCCESS Successfully queried LDAP groups:"
    # Save all group names for later validation
    FOUND_GROUPS=$(echo "$LDAP_GROUPS" | grep "cn: " | awk '{print $2}')
    if [ -z "$FOUND_GROUPS" ]; then
      echo "$WARNING No groups found in LDAP directory"
    else
      echo "$FOUND_GROUPS"
    fi
  fi
  
  # Check if expected users and groups exist
  echo "$INFO Verifying expected LDAP entries..."
  # Skip detailed verification if previous queries failed
  if [ -z "$LDAP_USERS" ] || [ -z "$LDAP_GROUPS" ]; then
    echo "$WARNING Skipping detailed verification due to previous query failures"
      echo "$FAILURE Expected user not found: $USER"
      USER_VALIDATION_SUCCESS=false
    fi
  done
  
  # Validate expected groups
  GROUP_VALIDATION_SUCCESS=true
  for GROUP in $EXPECTED_GROUPS; do
    if ! echo "$LDAP_GROUPS" | grep -q "cn: $GROUP"; then
      echo "$FAILURE Expected group not found: $GROUP"
      GROUP_VALIDATION_SUCCESS=false
    fi
  done
  
  # Final validation status
  if [ "$USER_VALIDATION_SUCCESS" = true ] && [ "$GROUP_VALIDATION_SUCCESS" = true ]; then
    echo "$SUCCESS LDAP validation completed successfully! All expected users and groups exist."
    return 0
  else
    echo "$FAILURE LDAP validation found issues. Some expected users or groups are missing."
    return 1
  fi
}

# Call validation function
validate_ldap
VALIDATION_RESULT=$?

# Final status
if [ "$VALIDATION_RESULT" -eq 0 ]; then
  echo "$SUCCESS LDAP configuration completed successfully!"
else
  echo "$FAILURE LDAP configuration incomplete - users and groups were not provisioned correctly!"
  
  # Only show logs if actual errors exist
  echo "$INFO Please check LLDAP container logs for errors:"
  docker logs --tail 20 "$LDAP_CONTAINER_NAME" | grep -i "error\|warn\|fail" || echo "No obvious errors found in logs"
fi

# Print information about LLDAP web interface
echo "$INFO You can access the LLDAP web interface at: $LLDAP_API_URL"
echo "$INFO Default admin username: admin"
echo "$INFO Default admin password: $LDAP_ADMIN_PASSWORD"
if [ -d "$TMP_DIR" ]; then
  rm -rf "$TMP_DIR"
fi

echo "$INFO You can access the LLDAP web interface at: $LLDAP_API_URL"
echo "$INFO Default admin username: admin"
echo "$INFO Default admin password: $LDAP_ADMIN_PASSWORD"

if [[ "$USER_COUNT" -gt 1 && "$GROUP_COUNT" -gt 0 ]]; then
  echo "$SUCCESS LDAP configuration complete!"
else
  echo "$FAILURE LDAP configuration incomplete - users and groups were not provisioned correctly!"
  echo "$INFO Please check LLDAP container logs for errors:"
  docker logs redstone-ldap-1 | tail -n 20
fi
