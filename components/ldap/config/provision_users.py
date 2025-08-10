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
