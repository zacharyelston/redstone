#!/bin/bash
# configure-redmica-ldap.sh
# Purpose: Configure LDAP authentication for Redmica
# Following "Built for Clarity" design philosophy - simple, direct and focused

set -e

echo "🔐 Configuring Redmica LDAP authentication..."

# Ensure directory exists
mkdir -p components/redmica/config

# Create a complete configuration.yml with LDAP settings included
# This follows the proper Redmica configuration format
cat > components/redmica/config/configuration.yml << EOF
# Redmica Main Configuration
# Following the "Built for Clarity" design philosophy - simple, modular, maintainable

production:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      address: "smtp"
      port: 1025
      domain: "redstone.local"
      
  # Default language
  default_language: en

  # Security settings
  session_store: :active_record_store
  
  # LDAP authentication configuration
  ldap:
    enabled: true
    host: ldap
    port: 3890
    account: 'uid=admin,ou=people,dc=redstone,dc=local'
    password: 'adminadmin'
    base_dn: 'ou=people,dc=redstone,dc=local'
    attr_login: uid
    attr_firstname: givenname
    attr_lastname: sn
    attr_mail: mail
    attr_username: cn
    # Group settings
    group_base_dn: 'ou=groups,dc=redstone,dc=local'
    group_attribute: cn
    member_attribute: member
    admin_group: 'admins'
    developers_group: 'developers'
    users_group: 'redmica_users'
    onthefly_register: true
    self_register: true
    tls: false
    timeout: 20
    
  # Attachment settings
  attachments_storage_path: files
  autologin_cookie_name: autologin
  autologin_cookie_path: /
  autologin_cookie_secure: false
  
  # REST API settings
  rest_api_enabled: true
  
  # SCM settings
  scm_subversion_command: svn
  scm_git_command: git
EOF

# Copy configuration to container
echo "📝 Copying LDAP configuration to Redmica container..."
docker cp components/redmica/config/configuration.yml redstone-redmica-1:/usr/src/redmine/config/

# Restart Redmica to apply changes
echo "🔄 Restarting Redmica to apply LDAP configuration..."
docker restart redstone-redmica-1

# Wait for Redmica to come back online
echo "⏳ Waiting for Redmica to restart with LDAP configuration..."
count=0
max_attempts=12  # 60 seconds total
while [ $count -lt $max_attempts ]; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q "200"; then
    echo "✅ Redmica is online with LDAP configuration"
    break
  fi
  echo "⏳ Still waiting for Redmica... ($(( count + 1 ))/$max_attempts)"
  sleep 5
  count=$((count + 1))
done

if [ $count -eq $max_attempts ]; then
  echo "⚠️ Timed out waiting for Redmica to come online. Check container logs."
  exit 1
fi

# Validate LDAP configuration
echo "🔍 Validating Redmica LDAP configuration..."
if docker exec redstone-redmica-1 grep -q "ldap:" /usr/src/redmine/config/configuration.yml; then
  echo "✅ LDAP configuration found in Redmica settings"
else
  echo "❌ LDAP configuration not found in Redmica settings"
  exit 1
fi

# Create LDAP AuthSource entry in Redmica database
echo "🔧 Creating LDAP authentication source in Redmica database..."

# Check if LDAP auth source already exists
LDAP_AUTH_COUNT=$(docker exec redstone-redmica-1 rails runner "puts AuthSource.where(type: 'AuthSourceLdap').count")

if [ "$LDAP_AUTH_COUNT" == "0" ]; then
  echo "📝 Creating new LDAP authentication source..."
  # Create LDAP authentication source using Rails console
  docker exec redstone-redmica-1 rails runner "
    ldap = AuthSourceLdap.new(
      name: 'LDAP',
      host: 'ldap',
      port: 3890,
      account: 'uid=admin,ou=people,dc=redstone,dc=local',
      account_password: 'adminadmin',
      base_dn: 'ou=people,dc=redstone,dc=local',
      attr_login: 'uid',
      attr_firstname: 'givenname',
      attr_lastname: 'sn',
      attr_mail: 'mail',
      onthefly_register: true
    )
    if ldap.save
      puts 'LDAP authentication source created successfully'
    else
      puts 'Failed to create LDAP authentication source:'
      puts ldap.errors.full_messages.join(', ')
      exit 1
    end
  "
else
  echo "✓ LDAP authentication source already exists"
fi

# Verify LDAP auth source was created
LDAP_AUTH_COUNT=$(docker exec redstone-redmica-1 rails runner "puts AuthSource.where(type: 'AuthSourceLdap').count")
if [ "$LDAP_AUTH_COUNT" -gt "0" ]; then
  echo "✅ LDAP authentication source configured successfully"
else
  echo "❌ Failed to create LDAP authentication source"
  exit 1
fi

echo "✅ Redmica LDAP configuration completed successfully"
echo "🔑 You can now log in with:"
echo "  Username: developer_user"
echo "  Password: devpassword"
echo "  URL: http://localhost:3000"
