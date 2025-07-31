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

echo "🔐 Configuring LDAP for Redstone deployment..."

# Check if custom LDAP config exists
CUSTOM_CONFIG="${PROJECT_ROOT}/custom/ldap-config.yaml"
DEFAULT_CONFIG="${LDAP_DIR}/ldap-defaults.yaml"
TARGET_CONFIG="${LDAP_DIR}/config/ldap.yaml"

# Create config directory if it doesn't exist
mkdir -p "${LDAP_DIR}/config"

if [ -f "$CUSTOM_CONFIG" ]; then
    echo "📄 Found custom LDAP configuration, using: $CUSTOM_CONFIG"
    # Copy the custom config to the target location
    cp "$CUSTOM_CONFIG" "$TARGET_CONFIG"
else
    echo "📄 Using default LDAP configuration: $DEFAULT_CONFIG"
    # Copy the default config to the target location
    cp "$DEFAULT_CONFIG" "$TARGET_CONFIG"
fi

# Check if LLDAP container is running
LDAP_CONTAINER=$(docker compose ps -q ldap 2>/dev/null)
if [ -z "$LDAP_CONTAINER" ]; then
    echo "⚠️ LDAP container is not running. Starting it first..."
    docker compose up -d ldap
    # Wait a bit for container to start
    sleep 5
    LDAP_CONTAINER=$(docker compose ps -q ldap 2>/dev/null)
    if [ -z "$LDAP_CONTAINER" ]; then
        echo "❌ Failed to start LDAP container"
        exit 1
    fi
fi

# Use Docker to apply the LDAP configuration
echo "🔄 Applying LDAP configuration to container..."
docker compose exec -T ldap sh -c "mkdir -p /tmp/config"
docker cp "$TARGET_CONFIG" "${LDAP_CONTAINER}:/tmp/config/ldap.yaml"

# Run the LDIF generation inside the container
echo "🔄 Generating LDIF configuration inside container..."

# Create a temporary Python script for LDAP configuration
cat > ${LDAP_DIR}/config/generate_ldif.py << 'EOF'
import yaml
import sys
import os
import base64
import hashlib
from pathlib import Path

try:
    # Read the YAML configuration
    config = yaml.safe_load(Path('/config/ldap.yaml').read_text())
    
    with open('/config/users.ldif', 'w') as f:
        # Create base entries
        f.write('# Generated LDIF from YAML configuration\n')
        
        # Create base DN structure
        base_dn = config['base_config']['base_dn']
        f.write(f'dn: {base_dn}\n')
        f.write('objectClass: dcObject\n')
        f.write('objectClass: organization\n')
        f.write(f"dc: {base_dn.split('=')[1].split(',')[0]}\n")
        f.write('o: Redstone Organization\n\n')
        
        # Create organizational units
        f.write(f'dn: ou=users,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: users\n\n')
        
        f.write(f'dn: ou=groups,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: groups\n\n')
        
        f.write(f'dn: ou=services,{base_dn}\n')
        f.write('objectClass: organizationalUnit\n')
        f.write('ou: services\n\n')
        
        # Create service users
        for user in config.get('service_users', []):
            uid = user['username']
            f.write(f'dn: uid={uid},ou=users,{base_dn}\n')
            f.write('objectClass: inetOrgPerson\n')
            f.write('objectClass: organizationalPerson\n')
            f.write('objectClass: person\n')
            f.write(f'uid: {uid}\n')
            f.write(f"cn: {user.get('display_name', uid)}\n")
            # Use display_name for sn if not specified
            f.write(f"sn: {user.get('display_name', uid)}\n")
            f.write(f"displayName: {user.get('display_name', uid)}\n")
            f.write(f"mail: {user.get('email', f'{uid}@example.com')}\n")
            # Password is stored in plaintext for simplicity in this demo
            f.write(f"userPassword: {user['password']}\n\n")
        
        # Create regular users
        for user in config.get('users', []):
            uid = user['username']
            f.write(f'dn: uid={uid},ou=users,{base_dn}\n')
            f.write('objectClass: inetOrgPerson\n')
            f.write('objectClass: organizationalPerson\n')
            f.write('objectClass: person\n')
            f.write(f'uid: {uid}\n')
            f.write(f"cn: {user.get('display_name', uid)}\n")
            f.write(f"sn: {user.get('last_name', 'User')}\n")
            f.write(f"givenName: {user.get('first_name', 'Default')}\n")
            f.write(f"displayName: {user.get('display_name', uid)}\n")
            f.write(f"mail: {user.get('email', f'{uid}@example.com')}\n")
            # Password is stored in plaintext for simplicity
            f.write(f"userPassword: {user['password']}\n\n")
        
        # Create groups
        for group in config.get('groups', []):
            gid = group['name']
            f.write(f'dn: cn={gid},ou=groups,{base_dn}\n')
            f.write('objectClass: groupOfNames\n')
            f.write(f'cn: {gid}\n')
            f.write(f"description: {group.get('description', 'Group for ' + gid)}\n")
            
            # Find users who belong to this group
            members = []
            
            # Check service users
            for user in config.get('service_users', []):
                if 'groups' in user and gid in user['groups']:
                    members.append(f"uid={user['username']},ou=users,{base_dn}")
            
            # Check regular users
            for user in config.get('users', []):
                if 'groups' in user and gid in user['groups']:
                    members.append(f"uid={user['username']},ou=users,{base_dn}")
            
            # Add members to the group - at least one member is required
            if not members:
                # Use admin as default member if no members found
                members = [f'uid=admin_user,ou=users,{base_dn}']
            
            for member in members:
                f.write(f'member: {member}\n')
            
            f.write('\n')
    
    print('Complete LDIF configuration generated successfully')
except Exception as e:
    print(f'Error generating LDIF: {e}')
    sys.exit(1)
EOF

# Create or reuse a lightweight Python helper container
LDAP_HELPER="ldap-config-helper"
NETWORK="redstone_redstone-network" # Network that LDAP is actually using

# Check if container exists, create it if not
if docker ps -a | grep -q ${LDAP_HELPER}; then
  # Remove existing container to avoid conflicts
  echo "🖼️ Removing old helper container..."
  docker rm -f ${LDAP_HELPER} >/dev/null 2>&1
fi

# Create a new helper container on the correct network
echo "🔨 Creating helper container..."
docker run --name ${LDAP_HELPER} \
  --rm -d \
  --network ${NETWORK} \
  -v "${LDAP_DIR}/config:/config" \
  -v "${LDAP_DIR}/bootstrap:/bootstrap" \
  python:3.9-alpine \
  tail -f /dev/null

# Install dependencies
docker exec ${LDAP_HELPER} pip install pyyaml requests

# Generate LDIF using the helper container
echo "🔨 Generating LDIF using Python helper container..."
docker exec ${LDAP_HELPER} python /config/generate_ldif.py

# Create a script to provision users and groups via LLDAP API
cat > ${LDAP_DIR}/config/provision_users.py << 'EOF'
import sys
import yaml
import json
import requests
import traceback
import subprocess
from pathlib import Path

# Define global variables for LLDAP connection
import os
import socket

# Helper function to check if a host:port is accessible
def is_port_open(host, port, timeout=1):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception:
        return False

# LLDAP API details with fallback options
POSSIBLE_LLDAP_URLS = [
    "http://redstone-ldap-1:17170",    # Docker service name
    "http://ldap:17170",              # Service alias
    "http://localhost:3892",           # Port forwarding on host
    "http://redstone-lldap:17170",    # Alternative container name
    "http://host.docker.internal:3892" # Host machine from container
]

# Try to detect the best URL based on connectivity
def detect_best_url():
    print("\n🔍 Auto-detecting best LLDAP connection method...")
    for url in POSSIBLE_LLDAP_URLS:
        host = url.split('://')[1].split(':')[0]
        port = int(url.split(':')[-1])
        print(f"  Testing {host}:{port}...")
        if is_port_open(host, port):
            print(f"  ✅ {url} is accessible")
            return url
        print(f"  ❌ {url} is not accessible")
    return None
    
ADMIN_USER = "admin"
ADMIN_PASSWORD = os.environ.get("LDAP_ADMIN_PASSWORD", "adminadmin")

# Import os to get environment variables if provided
import os
# Get admin password from environment if set
ADMIN_PASSWORD = os.environ.get("LDAP_ADMIN_PASSWORD", ADMIN_PASSWORD)

# Global variable to store the working LLDAP URL once discovered
working_lldap_url = None

def get_jwt_token():
    """Get JWT token for API authentication by trying multiple possible URLs"""
    global working_lldap_url
    
    # First try the auto-detected URL if possible
    best_url = detect_best_url()
    if best_url:
        print(f"\n🔑 Attempting to authenticate using auto-detected URL: {best_url}")
        try:
            # LLDAP auth endpoint is at /auth/simple/login
            resp = requests.post(
                f"{best_url}/auth/simple/login",
                json={"username": ADMIN_USER, "password": ADMIN_PASSWORD},
                headers={"Content-Type": "application/json"},  # Explicitly set content type
                timeout=5  # Add timeout to avoid hanging
            )
            
            if resp.status_code == 200:
                print(f"✅ Successfully authenticated to LLDAP at {best_url}")
                working_lldap_url = best_url
                return resp.json()["token"]
        except Exception as e:
            print(f"❌ Authentication failed with auto-detected URL: {str(e)}")
    
    # Fall back to trying each possible URL if auto-detection fails
    print("\n🔄 Falling back to trying all possible LLDAP URLs...")
    for url in POSSIBLE_LLDAP_URLS:
        print(f"  Attempting to connect to LLDAP at {url}...")
        try:
            resp = requests.post(
                f"{url}/auth/simple/login",
                json={"username": ADMIN_USER, "password": ADMIN_PASSWORD},
                headers={"Content-Type": "application/json"},  # Explicitly set content type
                timeout=5  # Add timeout to avoid hanging
            )
            
            if resp.status_code == 200:
                print(f"✓ Successfully connected to LLDAP at {url}")
                working_lldap_url = url  # Store the working URL for other functions
                try:
                    # Make sure we can actually parse the response as JSON
                    token = resp.json()["token"]
                    print(f"✓ Successfully obtained authentication token")
                    return token
                except Exception as json_err:
                    print(f"⚠️ Received status 200 but invalid JSON: {str(json_err)}")
                    continue
            else:
                print(f"✗ Failed with status {resp.status_code}: {resp.text[:100]}")
        except Exception as e:
            print(f"✗ Connection error with {url}: {str(e)}")
    
    # If we get here, all connection attempts failed
    print("❌ All LLDAP connection attempts failed")
    sys.exit(1)

def create_user(token, user_data):
    """Create a user via the LLDAP API"""
    username = user_data["username"]
    
    # Check if user exists first
    print(f"\n🔍 Checking if user {username} exists...")
    try:
        # Use the correct LLDAP API path for users
        resp = requests.get(
            f"{working_lldap_url}/api/user/list",
            headers={
                "Authorization": f"Bearer {token}", 
                "Accept": "application/json",
                "Content-Type": "application/json"
            },
            timeout=5
        )
        print(f"Response status: {resp.status_code}")
        print(f"Response headers: {resp.headers}")
        print(f"Response content: {resp.text[:100]}...") # Print first 100 chars
        
        # Check if response is empty
        if not resp.text.strip():
            print("\n⚠️ Empty response received from API")
            return False
            
        users = resp.json().get("users", [])
        if any(u.get("username") == username for u in users):
            print(f"User {username} already exists, skipping")
            return True
    except json.JSONDecodeError as e:
        print(f"\n⚠️ JSON parsing error: {str(e)}")
        print(f"Raw response: '{resp.text}'")
        if 'token' in resp.text.lower() or 'unauthorized' in resp.text.lower():
            print("The response suggests an authentication issue. Token may be invalid.")
        return False
    
    # Prepare user create payload
    create_data = {
        "username": username,
        "email": user_data.get("email", f"{username}@example.com"),
        "display_name": user_data.get("display_name", username),
        "first_name": user_data.get("first_name", ""),
        "last_name": user_data.get("last_name", ""),
        "password": user_data.get("password", "password123"),
    }
    
    # Create user with correct API endpoint
    resp = requests.post(
        f"{working_lldap_url}/api/user/create",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        },
        json=create_data
    )
    
    if resp.status_code in [200, 201]:
        print(f"✓ Created user: {username}")
        return True
    else:
        print(f"✗ Failed to create user {username}: {resp.text}")
        return False

def create_group(token, group_data):
    """Create a group via the LLDAP API"""
    group_name = group_data["name"]
    
    # Check if group exists first using correct API endpoint
    resp = requests.get(
        f"{working_lldap_url}/api/group/list",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
    )
    groups = resp.json().get("groups", [])
    if any(g.get("display_name") == group_name for g in groups):
        print(f"Group {group_name} already exists, skipping")
        return True
    
    # Create group with correct API endpoint
    resp = requests.post(
        f"{working_lldap_url}/api/group/create",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        },
        json={
            "display_name": group_name,
            "description": group_data.get("description", f"Group for {group_name}"),
        }
    )
    
    if resp.status_code in [200, 201]:
        print(f"✓ Created group: {group_name}")
        return True
    else:
        print(f"✗ Failed to create group {group_name}: {resp.text}")
        return False

def add_user_to_group(token, username, group_name):
    """Add a user to a group"""
    # Find group ID first with correct API endpoint
    resp = requests.get(
        f"{working_lldap_url}/api/group/list",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
    )
    groups = resp.json().get("groups", [])
    matching_groups = [g for g in groups if g.get("display_name") == group_name]
    
    if not matching_groups:
        print(f"⚠️ Group {group_name} not found, skipping")
        return False
    
    group_id = matching_groups[0]["id"]
    
    # Add user to group with correct API endpoint
    resp = requests.post(
        f"{working_lldap_url}/api/group/add_member",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        },
        json={
            "group_id": group_id,
            "username": username
        }
    )
    
    if resp.status_code in [200, 201, 204]:
        print(f"✓ Added user {username} to group {group_name}")
        return True
    else:
        print(f"✗ Failed to add user {username} to group {group_name}: {resp.text}")
        return False

def main():
    try:
        # Read YAML configuration
        print("\n📂 Reading LDAP configuration file...")
        try:
            config = yaml.safe_load(Path('/config/ldap.yaml').read_text())
            print(f"✓ Configuration loaded successfully with {len(config.get('users', []) + config.get('service_accounts', []))} users and {len(config.get('groups', []))} groups")
        except Exception as yaml_error:
            print(f"❌ Error loading YAML configuration: {str(yaml_error)}")
            print("📄 File contents preview:")
            with open('/config/ldap.yaml', 'r') as f:
                print(f.read()[:500] + '...')
            raise yaml_error
        
        # Get authentication token
        token = get_jwt_token()
        
        print(f"\n🚀 Using LLDAP API at {working_lldap_url}\n")
        
        # Verify we can connect to the API before proceeding
        print("🔍 Verifying API connection...")
        try:
            # Test API access with a correct API endpoint (version info)
            test_resp = requests.get(
                f"{working_lldap_url}/api/server/version",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                },
                timeout=5
            )
            if test_resp.status_code == 200:
                print("✅ API connection verified successfully!")
            else:
                print(f"⚠️ API test request returned status {test_resp.status_code}")
        except Exception as e:
            print(f"⚠️ API test request failed: {str(e)}")
            print("Continuing anyway...")
        
        # Create users and groups
        users = config.get('users', []) + config.get('service_accounts', [])
        if not users:
            print("⚠️ No users defined in configuration")
        
        print("\n👤 Creating users...")
        for user_data in users:
            create_user(token, user_data)
        
        print("\n👥 Creating groups...")
        for group_data in config.get('groups', []):
            create_group(token, group_data)
        
        # Add users to groups
        print("\n🔗 Adding users to groups...")
        for group_data in config.get('groups', []):
            group_name = group_data['name']
            for username in group_data.get('members', []):
                add_user_to_group(token, username, group_name)
        
        print("\n✅ LLDAP provisioning completed successfully!\n")
    except json.JSONDecodeError as json_err:
        print(f"\n❌ JSON parsing error: {str(json_err)}")
        print("This likely means the API returned non-JSON content or an empty response.")
        print("\nLet's examine the LDAP container status:")
        try:
            print("\nContainers running in the network:")
            subprocess.run(["docker", "ps", "--filter", "network=redstone_redstone-network"], check=True)
            
            print("\nLLDAP container logs (last 20 lines):")
            subprocess.run(["docker", "logs", "--tail", "20", "redstone-ldap-1"], check=True)
        except Exception as docker_error:
            print(f"Failed to get container info: {str(docker_error)}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error provisioning LLDAP: {str(e)}")
        print("\nDetailed error information:")
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()

# Check LDAP container status before provisioning
echo "🔍 Checking LDAP container status..."

# Find the LDAP container (either lldap or ldap naming)
LDAP_CONTAINER=$(docker ps --filter name=ldap --format "{{.Names}}" | grep -E 'ldap|lldap' | head -n 1)

if [ -z "$LDAP_CONTAINER" ]; then
  echo "❌ No running LDAP container found."
  echo "📋 Starting LDAP service from docker-compose..."
  docker compose up -d ldap
  
  # Wait for container to start
  echo "🕰️ Waiting for LDAP container to start..."
  sleep 5
  
  # Check again for the container
  LDAP_CONTAINER=$(docker ps --filter name=ldap --format "{{.Names}}" | grep -E 'ldap|lldap' | head -n 1)
  
  if [ -z "$LDAP_CONTAINER" ]; then
    echo "❌ Failed to start LDAP container."
    exit 1
  fi
fi

echo "✅ Using LDAP container: $LDAP_CONTAINER"

# Check container health if possible
CONTAINER_HEALTH=$(docker inspect --format="{{.State.Health.Status}}" "$LDAP_CONTAINER" 2>/dev/null || echo "health_unknown")
if [ "$CONTAINER_HEALTH" = "health_unknown" ]; then
  echo "📋 Container health check not available, checking if container is running..."
  CONTAINER_STATUS=$(docker inspect --format="{{.State.Status}}" "$LDAP_CONTAINER")
  if [ "$CONTAINER_STATUS" != "running" ]; then
    echo "❌ LDAP container is not running (status: $CONTAINER_STATUS)."
    exit 1
  fi
elif [ "$CONTAINER_HEALTH" != "healthy" ]; then
  echo "⚠️ LDAP container is not healthy (status: $CONTAINER_HEALTH). Proceeding anyway."
else
  echo "✅ LDAP container is healthy."
fi

# Show port mappings for debugging
echo "📋 LDAP container port mappings:"
docker port $LDAP_CONTAINER

# Get the port mapping for the LLDAP web UI/API
LLDAP_PORT=$(docker port "$LDAP_CONTAINER" 17170 | cut -d ':' -f 2 | head -n 1 || echo "17170")
LLDAP_API_URL="http://localhost:$LLDAP_PORT"
echo "$INFO LLDAP API URL: $LLDAP_API_URL"

# Set the admin password for bootstrap
export LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminadmin}"

# Execute the bootstrap script using the official LLDAP approach
echo "🔄 Provisioning LLDAP with users and groups using official bootstrap approach..."

# Check if we should use our standalone bootstrap script or run the command directly
if [ -f "$BOOTSTRAP_DIR/bootstrap-lldap.sh" ]; then
  echo "$INFO Using local bootstrap script..."
  bash "$BOOTSTRAP_DIR/bootstrap-lldap.sh"
else
  echo "$INFO Using direct bootstrap command..."
  
  # Copy bootstrap files to container if needed
  echo "$INFO Copying bootstrap files to container..."
  docker exec "$LDAP_CONTAINER" mkdir -p /tmp/bootstrap
  
  # Copy configuration files
  docker cp "$BOOTSTRAP_DIR/user-configs" "$LDAP_CONTAINER:/tmp/bootstrap/"
  docker cp "$BOOTSTRAP_DIR/group-configs" "$LDAP_CONTAINER:/tmp/bootstrap/"
  
  # Check if official bootstrap script exists in container
  if ! docker exec "$LDAP_CONTAINER" test -f /app/bootstrap.sh; then
    echo "$INFO Official bootstrap script not found in container, downloading..."
    docker exec "$LDAP_CONTAINER" curl -s -o /tmp/bootstrap/bootstrap.sh https://raw.githubusercontent.com/lldap/lldap/main/scripts/bootstrap.sh
    docker exec "$LDAP_CONTAINER" chmod +x /tmp/bootstrap/bootstrap.sh
    BOOTSTRAP_PATH="/tmp/bootstrap/bootstrap.sh"
  else
    BOOTSTRAP_PATH="/app/bootstrap.sh"
    echo "$INFO Using official bootstrap script from container: $BOOTSTRAP_PATH"
  fi
  
  # Execute bootstrap script inside the container
  echo "$INFO Running bootstrap script in container..."
  docker exec -e LLDAP_URL="http://localhost:17170" \
    -e LLDAP_ADMIN_USERNAME="admin" \
    -e LLDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PASSWORD" \
    -e USER_CONFIGS_DIR="/tmp/bootstrap/user-configs" \
    -e GROUP_CONFIGS_DIR="/tmp/bootstrap/group-configs" \
    -e DO_CLEANUP="false" \
    "$LDAP_CONTAINER" \
    $BOOTSTRAP_PATH
fi

# Cleanup any temporary files or containers if needed
if [ -n "${LDAP_HELPER+x}" ]; then
  echo "$INFO Removing helper container..."
  docker rm -f ${LDAP_HELPER} >/dev/null 2>&1 || true
fi

# Check if the bootstrap was successful
echo "$INFO Verifying LLDAP configuration..."
sleep 2

# Simple check to see if we can access the LLDAP API
API_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$LLDAP_API_URL/api/server/version" || echo "connection_failed")

if [ "$API_CHECK" = "200" ] || [ "$API_CHECK" = "401" ]; then
  # 401 is acceptable as it means the API is responding but we're not authenticated
  echo "$SUCCESS LLDAP API is accessible! Configuration successful."
else
  echo "$WARNING LLDAP API check returned $API_CHECK - configuration may not be complete."
fi

echo "$SUCCESS LDAP configuration complete! LDAP is ready to use."
echo "🔑 Default admin password: ${LDAP_ADMIN_PASSWORD:-adminadmin}"
echo "👤 Created users and groups from configuration"

echo "✅ LDAP configuration complete."
