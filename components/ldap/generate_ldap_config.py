#!/usr/bin/env python3
"""
LDAP Configuration Generator for Redstone

This script converts a YAML configuration file (ldap-defaults.yaml) into LDIF format
for provisioning LDAP users, groups, and organizational units during deployment.

Usage:
    python generate_ldap_config.py [--input INPUT_FILE] [--output OUTPUT_FILE]

Options:
    --input INPUT_FILE    Path to the YAML config file (default: ldap-defaults.yaml)
    --output OUTPUT_FILE  Path to the output LDIF file (default: config/users.ldif)
"""

import os
import sys
import yaml
import argparse
import datetime
import hashlib
import base64
import binascii
from pathlib import Path


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Generate LDAP config from YAML")
    parser.add_argument('--input', default='ldap-defaults.yaml',
                        help='Path to the input YAML config file')
    parser.add_argument('--output', default='config/users.ldif',
                        help='Path to the output LDIF file')
    parser.add_argument('--env', action='store_true',
                        help='Load passwords from environment variables')
    return parser.parse_args()


def load_config(file_path):
    """Load the YAML configuration file."""
    try:
        with open(file_path, 'r') as file:
            return yaml.safe_load(file)
    except Exception as e:
        print(f"Error loading configuration file: {e}", file=sys.stderr)
        sys.exit(1)


def get_password(username, password, use_env=False):
    """Get password from config or environment variable."""
    if use_env:
        env_var_name = f"LDAP_{username.upper()}_PASSWORD"
        return os.environ.get(env_var_name, password)
    return password


def generate_ldif(config, use_env=False):
    """Generate LDIF content from the configuration."""
    base_dn = config['base_config']['base_dn']
    domain_parts = base_dn.split(',')
    
    # Start with header and timestamp
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ldif = [
        f"# LDIF Export for {config['base_config']['domain']}",
        f"# Generated: {timestamp}",
        f"# Base DN: {base_dn}",
        "",
    ]
    
    # Create organizational units
    ous = {
        "users": "Users",
        "groups": "Groups",
        "services": "Service Accounts"
    }
    
    for ou_key, ou_name in ous.items():
        ldif.extend([
            f"dn: ou={ou_key},{base_dn}",
            "objectClass: organizationalUnit",
            "objectClass: top",
            f"ou: {ou_key}",
            f"description: {ou_name}",
            "",
        ])
    
    # Create groups
    for group in config['groups']:
        group_name = group['name']
        ldif.extend([
            f"dn: cn={group_name},ou=groups,{base_dn}",
            "objectClass: groupOfNames",
            "objectClass: top",
            f"cn: {group_name}",
            f"description: {group['description']}",
            # Start with a placeholder member that will be removed later
            f"member: cn=placeholder,ou=users,{base_dn}",
            "",
        ])
    
    # Create service users
    for user in config['service_users']:
        username = user['username']
        password = get_password(username, user['password'], use_env)
        email = user['email']
        
        ldif.extend([
            f"dn: cn={username},ou=services,{base_dn}",
            "objectClass: inetOrgPerson",
            "objectClass: organizationalPerson",
            "objectClass: person",
            "objectClass: top",
            f"cn: {username}",
            f"sn: {username}",
            f"uid: {username}",
            f"mail: {email}",
            f"displayName: {user['display_name']}",
            f"userPassword: {password}",
            "",
        ])
    
    # Create regular users
    for user in config['users']:
        username = user['username']
        password = get_password(username, user['password'], use_env)
        
        ldif.extend([
            f"dn: cn={username},ou=users,{base_dn}",
            "objectClass: inetOrgPerson",
            "objectClass: organizationalPerson",
            "objectClass: person",
            "objectClass: top",
            f"cn: {username}",
            f"uid: {username}",
            f"sn: {user['last_name']}",
            f"givenName: {user['first_name']}",
            f"displayName: {user['display_name']}",
            f"mail: {user['email']}",
            f"userPassword: {password}",
            "",
        ])
    
    # Add users to groups
    group_members = {}
    
    # First collect service user group memberships
    for user in config['service_users']:
        username = user['username']
        user_dn = f"cn={username},ou=services,{base_dn}"
        
        for group_name in user['groups']:
            if group_name not in group_members:
                group_members[group_name] = []
            group_members[group_name].append(user_dn)
    
    # Then collect regular user group memberships
    for user in config['users']:
        username = user['username']
        user_dn = f"cn={username},ou=users,{base_dn}"
        
        for group_name in user['groups']:
            if group_name not in group_members:
                group_members[group_name] = []
            group_members[group_name].append(user_dn)
    
    # Update groups with members
    for group_name, members in group_members.items():
        ldif.append(f"dn: cn={group_name},ou=groups,{base_dn}")
        ldif.append("changetype: modify")
        ldif.append("delete: member")
        ldif.append("member: cn=placeholder,ou=users," + base_dn)
        ldif.append("-")
        ldif.append("add: member")
        for member in members:
            ldif.append(f"member: {member}")
        ldif.append("")
    
    return "\n".join(ldif)


def save_ldif(content, file_path):
    """Save the generated LDIF content to a file."""
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as file:
        file.write(content)


def main():
    args = parse_args()
    config = load_config(args.input)
    ldif_content = generate_ldif(config, args.env)
    save_ldif(ldif_content, args.output)
    print(f"LDIF configuration generated successfully: {args.output}")


if __name__ == "__main__":
    main()
