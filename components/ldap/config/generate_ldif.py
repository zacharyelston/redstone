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
