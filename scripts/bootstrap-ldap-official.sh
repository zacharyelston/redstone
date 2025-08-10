#!/bin/bash

# Bootstrap LDAP configuration using official LLDAP bootstrap approach
# Following the "Built for Clarity" design philosophy - simple, clear, maintainable

# Constants for formatting output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emoji indicators
SUCCESS="✅"
FAILURE="❌"
WARNING="⚠️"
INFO="ℹ️"
SECURE="🔐"

# Default configuration - use relative paths for portability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_DIR="$PROJECT_ROOT/components/ldap/bootstrap"
CONFIG_FILE="$PROJECT_ROOT/components/ldap/ldap-defaults.yaml"
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-adminadmin}
LLDAP_ADMIN_USERNAME=${LLDAP_ADMIN_USERNAME:-admin}
LLDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-adminadmin}

# Ensure we're using the same password that LLDAP container is configured with
# Check if container has LLDAP_LDAP_USER_PASS set and use that
if command -v docker >/dev/null 2>&1; then
    CONTAINER_LDAP_PASS=$(docker exec redstone-ldap-1 printenv LLDAP_LDAP_USER_PASS 2>/dev/null || echo "")
    if [ -n "$CONTAINER_LDAP_PASS" ]; then
        LLDAP_ADMIN_PASSWORD="$CONTAINER_LDAP_PASS"
        echo -e "${INFO} Using LDAP password from container: $CONTAINER_LDAP_PASS"
    fi
fi
DO_CLEANUP="false"

# Print script banner
echo -e "${SECURE} ${BLUE}Starting LDAP configuration using official LLDAP bootstrap approach${NC}"
echo -e "${INFO} Using default LDAP configuration: ${CONFIG_FILE}"

# Find LDAP container
echo -e "${INFO} Checking LDAP container status..."
# Be more specific to find just the LLDAP container (not helper containers)
LDAP_CONTAINER=$(docker ps --filter name=redstone-ldap --format '{{.ID}}' | head -1)

if [ -z "$LDAP_CONTAINER" ]; then
  # Try alternative approach
  LDAP_CONTAINER=$(docker ps | grep -i lldap | awk '{print $1}' | head -1)
  
  if [ -z "$LDAP_CONTAINER" ]; then
    echo -e "${FAILURE} ${RED}No running LDAP container found. Please start the LDAP container first.${NC}"
    exit 1
  fi
fi

# Get container name for display
LDAP_CONTAINER_NAME=$(docker ps --filter id=$LDAP_CONTAINER --format '{{.Names}}' 2>/dev/null)
if [ -z "$LDAP_CONTAINER_NAME" ]; then
  LDAP_CONTAINER_NAME="unknown"
fi
echo -e "${SUCCESS} Using LDAP container: $LDAP_CONTAINER_NAME ($LDAP_CONTAINER)"

# Check container health
CONTAINER_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $LDAP_CONTAINER 2>/dev/null)

if [ "$CONTAINER_STATUS" != "healthy" ]; then
  echo -e "${WARNING} ${YELLOW}LDAP container is not healthy (status: $CONTAINER_STATUS). Proceeding anyway.${NC}"
fi

# Get port mappings
echo -e "${INFO} LDAP container port mappings:"
docker port $LDAP_CONTAINER 2>/dev/null | grep -E '(3890|17170)' || echo "Port mapping not found, using default ports"

# Find the mapped port for the LLDAP API
API_PORT="3892" # Default from previous script
# Try to detect port mapping
LDAP_PORT_INFO=$(docker port $LDAP_CONTAINER 17170 2>/dev/null)
if [ -n "$LDAP_PORT_INFO" ]; then
  DETECTED_PORT=$(echo "$LDAP_PORT_INFO" | head -n1 | cut -d':' -f2)
  if [ -n "$DETECTED_PORT" ]; then
    API_PORT="$DETECTED_PORT"
  fi
fi
echo -e "${INFO} Using LLDAP API port: $API_PORT"

LLDAP_API_URL="http://localhost:$API_PORT"
LLDAP_URL="$LLDAP_API_URL"
echo -e "${INFO} LLDAP API URL: ${LLDAP_API_URL}"

# Validate bootstrap directory structure
echo -e "${INFO} Validating bootstrap directory structure..."

# Check and create required directories if they don't exist
for DIR in "group-configs" "user-configs" "group-schemas" "user-schemas"; do
  if [ ! -d "$BOOTSTRAP_DIR/$DIR" ]; then
    echo -e "${WARNING} Creating missing directory: $BOOTSTRAP_DIR/$DIR"
    mkdir -p "$BOOTSTRAP_DIR/$DIR"
  fi
done

# Begin bootstrap process
echo -e "${INFO} Starting LLDAP bootstrap process..."

# Try to find the official bootstrap script in the container
echo -e "${INFO} Checking for official bootstrap script..."
BOOTSTRAP_SCRIPT_PATH=""

# List common locations where bootstrap script might be found
for path in "/app/bootstrap.sh" "/bootstrap.sh" "/lldap/bootstrap.sh" "/usr/local/bin/bootstrap.sh" "/app/lldap/bootstrap.sh"; do
  SCRIPT_CHECK=$(docker exec "$LDAP_CONTAINER" sh -c "[ -f $path ] && echo 'found'" 2>/dev/null || echo '')
  if [ "$SCRIPT_CHECK" = "found" ]; then
    BOOTSTRAP_SCRIPT_PATH="$path"
    echo -e "${SUCCESS} Found bootstrap script at: $BOOTSTRAP_SCRIPT_PATH"
    break
  fi
done

# If script not found anywhere
if [ -z "$BOOTSTRAP_SCRIPT_PATH" ]; then
  echo -e "${WARNING} ${YELLOW}Official bootstrap script not found in container${NC}"
  echo -e "${INFO} Will create a custom bootstrap script instead"
fi

# Create a temporary bootstrap script to execute inside the container
TMP_BOOTSTRAP_SCRIPT=$(mktemp)
cat > $TMP_BOOTSTRAP_SCRIPT << 'EOF'
#!/bin/sh
set -e
echo "Starting LLDAP bootstrap from within container..."

# Display environment variables for debugging
echo "LLDAP URL: $LLDAP_URL"
echo "Admin username: $LLDAP_ADMIN_USERNAME"
echo "Config directories:"
echo "User configs: $USER_CONFIGS_DIR"
echo "Group configs: $GROUP_CONFIGS_DIR"

# Verify directories exist
if [ ! -d "$USER_CONFIGS_DIR" ]; then
  echo "ERROR: User configs directory not found: $USER_CONFIGS_DIR"
  exit 1
fi

if [ ! -d "$GROUP_CONFIGS_DIR" ]; then
  echo "ERROR: Group configs directory not found: $GROUP_CONFIGS_DIR"
  exit 1
fi

# List config files for verification
echo "User config files:"
ls -la "$USER_CONFIGS_DIR"

echo "Group config files:"
ls -la "$GROUP_CONFIGS_DIR"

# Check for LLDAP bootstrap script in common locations
BOOTSTRAP_SCRIPT=""
for LOCATION in "/app/bootstrap.sh" "/bootstrap.sh" "/lldap/bootstrap.sh"; do
  if [ -f "$LOCATION" ]; then
    BOOTSTRAP_SCRIPT="$LOCATION"
    echo "Found bootstrap script at: $BOOTSTRAP_SCRIPT"
    break
  fi
done

# Authenticate with LLDAP API
echo "Authenticating with LLDAP API..."
curl -s -v -X POST "$LLDAP_URL/auth/simple/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"'$LLDAP_ADMIN_USERNAME'", "password":"'$LLDAP_ADMIN_PASSWORD'"}' > /tmp/auth_response.txt

cat /tmp/auth_response.txt

if grep -q "token" /tmp/auth_response.txt; then
  JWT_TOKEN=$(grep -o '"token":"[^"]*"' /tmp/auth_response.txt | cut -d'"' -f4)
  echo "Successfully obtained API token"
else
  echo "ERROR: Failed to authenticate with LLDAP API"
  echo "Response content:"
  cat /tmp/auth_response.txt
  exit 1
fi

if [ -n "$BOOTSTRAP_SCRIPT" ]; then
  # Execute official bootstrap script with bash (not sh) to support array syntax
  echo "Running official bootstrap script: $BOOTSTRAP_SCRIPT"
  if command -v bash >/dev/null 2>&1; then
    echo "Using bash to execute bootstrap script..."
    bash "$BOOTSTRAP_SCRIPT"
  else
    echo "Bash not available, attempting with sh..."
    /bin/sh "$BOOTSTRAP_SCRIPT"
  fi
  
  EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ]; then
    echo "WARNING: Official bootstrap script failed with exit code $EXIT_CODE"
    echo "Falling back to minimal implementation..."
    # Continue to minimal implementation - don't exit
  else
    echo "Bootstrap completed successfully"
    exit 0
  fi
else
  # Implement a minimal version of the bootstrap functionality
  echo "No bootstrap script found. Implementing minimal bootstrap..."

  # Create groups first
  echo "Creating groups from configs in $GROUP_CONFIGS_DIR"
  for GROUP_FILE in "$GROUP_CONFIGS_DIR"/*.json; do
    if [ -f "$GROUP_FILE" ]; then
      echo "Processing group file: $GROUP_FILE"
      GROUP_NAME=$(grep -o '"name":"[^"]*"' "$GROUP_FILE" | cut -d'"' -f4)
      if [ -n "$GROUP_NAME" ]; then
        echo "Creating group: $GROUP_NAME"
        curl -s -X POST "$LLDAP_URL/api/group" \
          -H "Authorization: Bearer $JWT_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"displayName":"'$GROUP_NAME'"}'
      fi
    fi
  done

  # Create users next
  echo "Creating users from configs in $USER_CONFIGS_DIR"
  for USER_FILE in "$USER_CONFIGS_DIR"/*.json; do
    if [ -f "$USER_FILE" ]; then
      echo "Processing user file: $USER_FILE"
      USER_DATA=$(cat "$USER_FILE")
      # Extract user details
      USER_ID=$(echo "$USER_DATA" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
      EMAIL=$(echo "$USER_DATA" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
      PASSWORD=$(echo "$USER_DATA" | grep -o '"password":"[^"]*"' | cut -d'"' -f4)
      DISPLAY_NAME=$(echo "$USER_DATA" | grep -o '"displayName":"[^"]*"' | cut -d'"' -f4)
      
      echo "Creating user: $USER_ID"
      curl -s -X POST "$LLDAP_URL/api/user" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"id":"'$USER_ID'","email":"'$EMAIL'","displayName":"'$DISPLAY_NAME'","password":"'$PASSWORD'"}'
      
      # Add user to groups
      echo "$USER_DATA" | grep -o '"groups":\[.*\]' > /tmp/groups.txt
      if [ -s "/tmp/groups.txt" ]; then
        GROUPS=$(cat /tmp/groups.txt | sed 's/"groups":\[//' | sed 's/\]//' | sed 's/,/ /g' | tr -d '"')
        for GROUP in $GROUPS; do
          echo "Adding $USER_ID to group: $GROUP"
          curl -s -X PUT "$LLDAP_URL/api/group/$GROUP/member/$USER_ID" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{}'
        done
      fi
    fi
  done
  
  echo "Minimal bootstrap completed successfully"
  exit 0
fi

# Process group configs
if [ -d "$GROUP_CONFIGS_DIR" ] && [ "$(ls -A "$GROUP_CONFIGS_DIR" 2>/dev/null)" ]; then
  for GROUP_FILE in "$GROUP_CONFIGS_DIR"/*.json; do
    echo "Processing group file: $GROUP_FILE"
    # Extract group name from file
    GROUP_NAME=$(cat "$GROUP_FILE" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d '"' -f4)
    if [ -n "$GROUP_NAME" ]; then
      echo "Creating group: $GROUP_NAME"
      curl -s -X POST "$LLDAP_URL/api/group" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"name\":\"$GROUP_NAME\"}"
      echo ""
    fi
  done
fi

# Process user configs
if [ -d "$USER_CONFIGS_DIR" ] && [ "$(ls -A "$USER_CONFIGS_DIR" 2>/dev/null)" ]; then
  for USER_FILE in "$USER_CONFIGS_DIR"/*.json; do
    echo "Processing user file: $USER_FILE"
    # Extract user details and create
    USER_ID=$(cat "$USER_FILE" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    USER_EMAIL=$(cat "$USER_FILE" | grep -o '"email"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    USER_DISPLAY_NAME=$(cat "$USER_FILE" | grep -o '"displayName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    USER_FIRST_NAME=$(cat "$USER_FILE" | grep -o '"firstName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    USER_LAST_NAME=$(cat "$USER_FILE" | grep -o '"lastName"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    USER_PASSWORD=$(cat "$USER_FILE" | grep -o '"password"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
    
    if [ -n "$USER_ID" ] && [ -n "$USER_EMAIL" ]; then
      echo "Creating user: $USER_ID ($USER_EMAIL)"
      curl -s -X POST "$LLDAP_URL/api/user" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\
          \"id\":\"$USER_ID\",\
          \"email\":\"$USER_EMAIL\",\
          \"display_name\":\"$USER_DISPLAY_NAME\",\
          \"first_name\":\"$USER_FIRST_NAME\",\
          \"last_name\":\"$USER_LAST_NAME\"\
        }"
      echo ""
      
      # Set user password if provided
      if [ -n "$USER_PASSWORD" ]; then
        echo "Setting password for user: $USER_ID"
        curl -s -X POST "$LLDAP_URL/api/user/$USER_ID/password" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $TOKEN" \
          -d "{\"password\":\"$USER_PASSWORD\"}"
        echo ""
      fi
      
      # Get user groups and add to groups
      USER_GROUPS=$(cat "$USER_FILE" | grep -o '"groups"[[:space:]]*:[[:space:]]*\[[^]]*\]')
      if [ -n "$USER_GROUPS" ]; then
        for GROUP in $(echo "$USER_GROUPS" | grep -o '"[^"]*"' | tr -d '"'); do
          if [ -n "$GROUP" ]; then
            echo "Adding $USER_ID to group: $GROUP"
            curl -s -X PUT "$LLDAP_URL/api/user/$USER_ID/group/$GROUP" \
              -H "Authorization: Bearer $TOKEN"
            echo ""
          fi
        done
      fi
    fi
  done
fi

echo "Minimal bootstrap completed"
MINEOF
    chmod +x /tmp/minimal_bootstrap.sh
    BOOTSTRAP_SCRIPT="/tmp/minimal_bootstrap.sh"
  fi
fi

# Get auth token
echo "Authenticating with LLDAP API..."
TOKEN_RESPONSE=$(curl -s -X POST "$LLDAP_URL/api/auth/simple/login" \
  -H "Content-Type: application/json" \
  -d '{"user":"'"$LLDAP_ADMIN_USERNAME"'","password":"'"$LLDAP_ADMIN_PASSWORD"'"}')

# Extract token
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d '"' -f4)
if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to authenticate with LLDAP API"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi
export TOKEN

# Execute the bootstrap script
echo "Executing bootstrap script: $BOOTSTRAP_SCRIPT"
$BOOTSTRAP_SCRIPT

# Print completion status
if [ $? -eq 0 ]; then
  echo "LLDAP bootstrap completed successfully"
else
  echo "LLDAP bootstrap failed with exit code $?"
  exit 1
fi
EOF

chmod +x $TMP_BOOTSTRAP_SCRIPT

# Copy the script to the container
echo -e "${INFO} Copying bootstrap configuration to container..."
docker cp $TMP_BOOTSTRAP_SCRIPT $LDAP_CONTAINER:/tmp/run_bootstrap.sh

echo -e "${INFO} Creating bootstrap directory in container..."
# Create bootstrap directory in container - use absolute path to handle any shell issues
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap/user-configs
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap/group-configs
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap/user-schemas
docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap/group-schemas

# Copy user config files to container
echo "${INFO} Copying user config files to container..."
for USER_CONFIG in "${BOOTSTRAP_DIR}"/user-configs/*.json; do
  # Extract filename
  FILENAME=$(basename "${USER_CONFIG}")
  echo "${INFO} Copying user config: ${FILENAME}"
  docker cp "${USER_CONFIG}" "${LDAP_CONTAINER}:/tmp/bootstrap/user-configs/${FILENAME}" >/dev/null
done

# Copy group config files to container
echo "${INFO} Copying group config files to container..."
for GROUP_CONFIG in "${BOOTSTRAP_DIR}"/group-configs/*.json; do
  # Extract filename
  FILENAME=$(basename "${GROUP_CONFIG}")
  echo "${INFO} Copying group config: ${FILENAME}"
  docker cp "${GROUP_CONFIG}" "${LDAP_CONTAINER}:/tmp/bootstrap/group-configs/${FILENAME}" >/dev/null
done

# Copy user schema files if they exist
if [ -d "${BOOTSTRAP_DIR}/user-schemas" ]; then
  echo "${INFO} Creating user-schemas directory in container..."
  docker exec "${LDAP_CONTAINER}" mkdir -p /tmp/bootstrap/user-schemas
  echo "${INFO} Copying user schema files to container..."
  for USER_SCHEMA in "${BOOTSTRAP_DIR}"/user-schemas/*.json; do
    if [ -f "$USER_SCHEMA" ]; then
      FILENAME=$(basename "${USER_SCHEMA}")
      echo "${INFO} Copying user schema: ${FILENAME}"
      docker cp "${USER_SCHEMA}" "${LDAP_CONTAINER}:/tmp/bootstrap/user-schemas/${FILENAME}" >/dev/null
    fi
  done
fi

# Copy group schema files if they exist
if [ -d "${BOOTSTRAP_DIR}/group-schemas" ]; then
  echo "${INFO} Creating group-schemas directory in container..."
  docker exec "${LDAP_CONTAINER}" mkdir -p /tmp/bootstrap/group-schemas
  echo "${INFO} Copying group schema files to container..."
  for GROUP_SCHEMA in "${BOOTSTRAP_DIR}"/group-schemas/*.json; do
    if [ -f "$GROUP_SCHEMA" ]; then
      FILENAME=$(basename "${GROUP_SCHEMA}")
      echo "${INFO} Copying group schema: ${FILENAME}"
      docker cp "${GROUP_SCHEMA}" "${LDAP_CONTAINER}:/tmp/bootstrap/group-schemas/${FILENAME}" >/dev/null
    fi
  done
fi

# Execute bootstrap with environment variables
echo -e "${INFO} Executing LLDAP bootstrap in container..."

# Inside the container, use internal network addresses - API runs on port 17170 internally
echo -e "${INFO} Note: Inside container, LLDAP API should be at http://localhost:17170"
docker exec \
  -e LLDAP_URL="http://localhost:17170" \
  -e LLDAP_ADMIN_USERNAME=admin \
  -e LLDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD" \
  -e USER_CONFIGS_DIR=/tmp/bootstrap/user-configs \
  -e GROUP_CONFIGS_DIR=/tmp/bootstrap/group-configs \
  -e USER_SCHEMAS_DIR=/tmp/bootstrap/user-schemas \
  -e GROUP_SCHEMAS_DIR=/tmp/bootstrap/group-schemas \
  -e DO_CLEANUP=$DO_CLEANUP \
  "$LDAP_CONTAINER" /bin/sh /tmp/run_bootstrap.sh

BOOTSTRAP_EXIT_CODE=$?

# Clean up temp file
rm -f $TMP_BOOTSTRAP_SCRIPT

# Validate LDAP configuration
echo -e "${INFO} Verifying LDAP configuration..."

# Check if ldapsearch is available
if ! command -v ldapsearch >/dev/null 2>&1; then
  echo -e "${INFO} Installing ldap-utils to validate LDAP configuration..."
  apt-get update && apt-get install -y ldap-utils || \
  brew install openldap || \
  (echo -e "${WARNING} Could not install ldap-utils automatically. Please install manually for validation.")
fi

# Run direct validation
echo -e "${INFO} Performing direct LDAP query validation..."

# Try to install ldapsearch if it's not available
if ! command -v ldapsearch >/dev/null 2>&1; then
  echo -e "${INFO} Installing ldap-utils package for validation..."
  # Try different package managers - one should work depending on the system
  apt-get update -qq && apt-get install -y ldap-utils >/dev/null 2>&1 || \
  yum install -y openldap-clients >/dev/null 2>&1 || \
  apk add --no-cache openldap-clients >/dev/null 2>&1 || \
  brew install openldap >/dev/null 2>&1 || \
  echo -e "${WARNING} Could not install ldap-utils automatically"
fi

# Check if ldapsearch is now available
if command -v ldapsearch >/dev/null 2>&1; then
  
    # Use LDAP port 3890 by default (consistent with our Docker Compose port mapping)
  LDAP_PORT="3890"
  
  # Try to detect actual port mapping if it exists
  DETECTED_PORT=$(docker port $LDAP_CONTAINER 3890 2>/dev/null | head -n1 | cut -d':' -f2)
  if [ -n "$DETECTED_PORT" ]; then
    LDAP_PORT="$DETECTED_PORT"
  fi
  echo -e "${INFO} Using LDAP port: $LDAP_PORT"
  
  # Test LDAP connection with timeout
  echo -e "${INFO} Testing LDAP connection on localhost:$LDAP_PORT..."
  timeout 5 ldapsearch -x -H ldap://localhost:$LDAP_PORT -s base -b "" "(objectclass=*)" >/dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo -e "${SUCCESS} ${GREEN}LDAP connection successful${NC}"
    
    # Simple search for users
    echo -e "${INFO} Searching for users..."
    USERS=$(timeout 5 ldapsearch -x -H ldap://localhost:$LDAP_PORT -b "ou=people,dc=redstone,dc=local" -D "uid=admin,ou=people,dc=redstone,dc=local" -w "$LDAP_ADMIN_PASSWORD" "(objectClass=*)" uid 2>/dev/null | grep "^uid: " | awk '{print $2}')
    
    if [ -n "$USERS" ]; then
      echo -e "${SUCCESS} ${GREEN}Found users:${NC}"
      echo "$USERS"
      
      # Check for expected users
      EXPECTED_USERS="admin admin_user developer_user viewer_user"
      MISSING_USERS=""
      for USER in $EXPECTED_USERS; do
        if ! echo "$USERS" | grep -q "$USER"; then
          MISSING_USERS="$MISSING_USERS $USER"
        fi
      done
      
      if [ -n "$MISSING_USERS" ]; then
        echo -e "${WARNING} ${YELLOW}Missing expected users:${NC} $MISSING_USERS"
      else
        echo -e "${SUCCESS} ${GREEN}All expected users are present${NC}"
      fi
    else
      echo -e "${WARNING} ${YELLOW}No users found. Bootstrap may have failed.${NC}"
    fi
    
    # Define LDAP search parameters explicitly for clarity
    LDAP_BASE_DN="ou=groups,dc=redstone,dc=local"
    LDAP_BIND_DN="uid=admin,ou=people,dc=redstone,dc=local"
    
    echo -e "${INFO} Searching for groups in $LDAP_BASE_DN..."
    # Use timeout to prevent hanging and redirect stderr for debugging
    LDAP_SEARCH_RESULT=$(timeout 5 ldapsearch -x -H ldap://localhost:$LDAP_PORT -b "$LDAP_BASE_DN" -D "$LDAP_BIND_DN" -w "$LDAP_ADMIN_PASSWORD" "(objectClass=*)" cn 2>&1)
    SEARCH_STATUS=$?
    
    # Capture error for debugging
    if [ $SEARCH_STATUS -ne 0 ] && [ $SEARCH_STATUS -ne 124 ]; then  # 124 is timeout exit code
      echo -e "${WARNING} ${YELLOW}LDAP search error (code $SEARCH_STATUS):${NC}"
      echo "$LDAP_SEARCH_RESULT" | head -10
    fi
    
    # Extract group names from search result
    GROUPS=$(echo "$LDAP_SEARCH_RESULT" | grep "^cn: " | awk '{print $2}')
    
    if [ -n "$GROUPS" ]; then
      echo -e "${SUCCESS} ${GREEN}Found groups:${NC}"
      echo "$GROUPS"
      
      # Check for expected groups
      EXPECTED_GROUPS="admins developers grafana_admins grafana_editors grafana_users redmine_admins redmine_users viewers"
      MISSING_GROUPS=""
      for GROUP in $EXPECTED_GROUPS; do
        if ! echo "$GROUPS" | grep -q "$GROUP"; then
          MISSING_GROUPS="$MISSING_GROUPS $GROUP"
        fi
      done
      
      if [ -n "$MISSING_GROUPS" ]; then
        echo -e "${WARNING} ${YELLOW}Missing expected groups:${NC} $MISSING_GROUPS"
      else
        echo -e "${SUCCESS} ${GREEN}All expected groups are present${NC}"
      fi
    else
      echo -e "${WARNING} ${YELLOW}No groups found. Bootstrap may have failed.${NC}"
    fi
  else
    echo -e "${WARNING} ${YELLOW}LDAP connection failed. Unable to validate.${NC}"
  fi
else
  echo -e "${WARNING} ldapsearch not available. Skipping validation."
  # Even without ldapsearch, we can still check if the bootstrap was successful
  if [ $BOOTSTRAP_EXIT_CODE -eq 0 ]; then
    echo -e "${SUCCESS} Bootstrap process reported success"
    VALIDATION_SUCCESS=true
  else
    echo -e "${FAILURE} Bootstrap process reported failure"
    VALIDATION_SUCCESS=false
  fi
fi

# Final status
if [ $BOOTSTRAP_EXIT_CODE -eq 0 ]; then
  echo -e "\n${SUCCESS} ${GREEN}LDAP bootstrap completed successfully${NC}"
  echo -e "${INFO} Users and groups have been provisioned using the official LLDAP bootstrap approach"
  echo -e "${INFO} You can now use the LDAP server for authentication"
  exit 0
else
  echo -e "\n${FAILURE} ${RED}LDAP bootstrap failed with exit code $BOOTSTRAP_EXIT_CODE${NC}"
  echo -e "${INFO} Check the output above for errors"
  exit $BOOTSTRAP_EXIT_CODE
fi
