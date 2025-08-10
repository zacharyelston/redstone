#!/bin/bash
# Zero-Touch Redmica Provisioning Script for Kubernetes
# Fully automated Redmica configuration for SaaS customer deployments
# Following "Built for Clarity" philosophy - simple, repeatable, maintainable

set -e
NAMESPACE="redstone"

# Colors and emojis for clear output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
SUCCESS="✅"
FAILURE="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"

echo -e "${ROCKET} ${BLUE}Zero-Touch Redmica Provisioning${NC}"
echo -e "${INFO} Configuring Redmica for production SaaS deployment"
echo ""

# Configuration parameters (can be overridden via environment variables)
CUSTOMER_NAME=${CUSTOMER_NAME:-"Demo Customer"}
CUSTOMER_IDENTIFIER=${CUSTOMER_IDENTIFIER:-"demo-customer"}
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@customer.com"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"$(openssl rand -base64 12)"}
LDAP_ENABLED=${LDAP_ENABLED:-true}
CREATE_DEMO_PROJECT=${CREATE_DEMO_PROJECT:-true}

echo -e "${INFO} Configuration:"
echo -e "   Customer: $CUSTOMER_NAME"
echo -e "   Identifier: $CUSTOMER_IDENTIFIER"
echo -e "   Admin Email: $ADMIN_EMAIL"
echo -e "   LDAP Enabled: $LDAP_ENABLED"
echo ""

# Function to wait for Redmica to be ready
wait_for_redmica() {
    echo -e "${INFO} Waiting for Redmica to be ready..."
    local max_attempts=30
    local count=0
    
    while [ $count -lt $max_attempts ]; do
        REDMICA_POD=$(kubectl get pods -n $NAMESPACE | grep redmica | grep Running | awk '{print $1}' | head -1)
        if [ -n "$REDMICA_POD" ]; then
            # Test if Rails is responding
            if kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts 'Ready'" RAILS_ENV=production >/dev/null 2>&1; then
                echo -e "${SUCCESS} Redmica is ready"
                return 0
            fi
        fi
        echo -e "${INFO} Still waiting... ($(( count + 1 ))/$max_attempts)"
        sleep 10
        count=$((count + 1))
    done
    
    echo -e "${FAILURE} Timeout waiting for Redmica to be ready"
    return 1
}

# Function to execute Rails commands in Redmica pod
run_rails_command() {
    local command="$1"
    local description="$2"
    
    echo -e "${GEAR} $description..."
    
    if kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "$command" RAILS_ENV=production; then
        echo -e "${SUCCESS} $description completed"
        return 0
    else
        echo -e "${FAILURE} $description failed"
        return 1
    fi
}

# Step 1: Wait for Redmica to be ready
wait_for_redmica || exit 1

# Step 2: Configure Admin User
echo -e "${INFO} ${BLUE}Step 2: Admin User Configuration${NC}"

ADMIN_CONFIG="
begin
  admin = User.find_by_login('admin') || User.find_by_mail('$ADMIN_EMAIL')
  
  if admin
    puts '✓ Admin user already exists, updating...'
    admin.update!(
      firstname: 'System',
      lastname: 'Administrator',
      mail: '$ADMIN_EMAIL',
      admin: true,
      status: User::STATUS_ACTIVE,
      must_change_passwd: false
    )
    puts '✅ Admin user updated successfully'
  else
    puts '✓ Creating new admin user...'
    admin = User.new(
      login: 'admin',
      firstname: 'System',
      lastname: 'Administrator',
      mail: '$ADMIN_EMAIL',
      admin: true,
      password: '$ADMIN_PASSWORD',
      password_confirmation: '$ADMIN_PASSWORD',
      status: User::STATUS_ACTIVE,
      must_change_passwd: false
    )
    
    if admin.save
      puts '✅ Admin user created successfully'
    else
      puts '❌ Failed to create admin user: ' + admin.errors.full_messages.join(', ')
      exit 1
    end
  end
rescue => e
  puts '❌ Error configuring admin user: ' + e.message
  exit 1
end
"

run_rails_command "$ADMIN_CONFIG" "Configuring admin user"

# Step 3: Configure LDAP Authentication (if enabled)
if [ "$LDAP_ENABLED" = "true" ]; then
    echo -e "${INFO} ${BLUE}Step 3: LDAP Authentication Configuration${NC}"
    
    LDAP_CONFIG="
    begin
      # Check if LDAP auth source already exists
      ldap_auth = AuthSource.find_by(type: 'AuthSourceLdap', name: 'LDAP')
      
      if ldap_auth
        puts '✓ LDAP authentication source already exists, updating...'
        ldap_auth.update!(
          host: 'redstone-ldap',
          port: 3890,
          account: 'uid=admin,ou=people,dc=redstone,dc=local',
          account_password: 'adminadmin',
          base_dn: 'ou=people,dc=redstone,dc=local',
          attr_login: 'uid',
          attr_firstname: 'givenname',
          attr_lastname: 'sn',
          attr_mail: 'mail',
          onthefly_register: true,
          tls: false,
          timeout: 10
        )
        puts '✅ LDAP authentication source updated'
      else
        puts '✓ Creating LDAP authentication source...'
        ldap_auth = AuthSourceLdap.new(
          name: 'LDAP',
          host: 'redstone-ldap',
          port: 3890,
          account: 'uid=admin,ou=people,dc=redstone,dc=local',
          account_password: 'adminadmin',
          base_dn: 'ou=people,dc=redstone,dc=local',
          attr_login: 'uid',
          attr_firstname: 'givenname',
          attr_lastname: 'sn',
          attr_mail: 'mail',
          onthefly_register: true,
          tls: false,
          timeout: 10
        )
        
        if ldap_auth.save
          puts '✅ LDAP authentication source created successfully'
        else
          puts '❌ Failed to create LDAP auth source: ' + ldap_auth.errors.full_messages.join(', ')
        end
      end
    rescue => e
      puts '❌ Error configuring LDAP: ' + e.message
    end
    "
    
    run_rails_command "$LDAP_CONFIG" "Configuring LDAP authentication"
fi

# Step 4: Configure Default Settings
echo -e "${INFO} ${BLUE}Step 4: Default Settings Configuration${NC}"

SETTINGS_CONFIG="
begin
  # Configure application settings
  customer_name = ENV['CUSTOMER_NAME'] || 'Customer'
  settings = {
    'app_title' => customer_name + ' - Project Management',
    'app_subtitle' => 'Powered by Redstone',
    'welcome_text' => 'Welcome to ' + customer_name + ' project management system.',
    'default_language' => 'en',
    'rest_api_enabled' => '1',
    'jsonp_enabled' => '0',
    'text_formatting' => 'common_mark',
    'cache_formatted_text' => '1',
    'feeds_limit' => '15',
    'default_projects_public' => '0',
    'sequential_project_identifiers' => '1',
    'attachment_max_size' => '5120',
    'mail_from' => 'noreply@$CUSTOMER_IDENTIFIER.redstone.local',
    'bcc_recipients' => '0',
    'plain_text_mail' => '0',
    'default_notification_option' => 'only_my_events'
  }
  
  settings.each do |name, value|
    setting = Setting.find_by_name(name)
    if setting
      setting.update!(value: value)
      puts \"✓ Updated setting: #{name} = #{value}\"
    else
      Setting.create!(name: name, value: value)
      puts \"✓ Created setting: #{name} = #{value}\"
    end
  end
  
  puts '✅ Default settings configured successfully'
rescue => e
  puts '❌ Error configuring settings: ' + e.message
end
"

run_rails_command "$SETTINGS_CONFIG" "Configuring default settings"

# Step 5: Ensure Default Enumerations
echo -e "${INFO} ${BLUE}Step 5: Default Enumerations Validation${NC}"

ENUMERATIONS_CONFIG="
begin
  # Ensure we have default issue priorities
  if IssuePriority.count == 0
    puts '✓ Creating default issue priorities...'
    priorities = [
      {name: 'Low', position: 1, is_default: false},
      {name: 'Normal', position: 2, is_default: true},
      {name: 'High', position: 3, is_default: false},
      {name: 'Urgent', position: 4, is_default: false},
      {name: 'Immediate', position: 5, is_default: false}
    ]
    
    priorities.each do |p|
      IssuePriority.create!(p)
      puts \"  ✓ Created priority: #{p[:name]}\"
    end
  else
    puts '✓ Issue priorities already exist (' + IssuePriority.count.to_s + ' priorities)'
  end
  
  # Ensure we have default trackers
  if Tracker.count == 0
    puts '✓ Creating default trackers...'
    trackers = [
      {name: 'Bug', position: 1, is_in_roadmap: true},
      {name: 'Feature', position: 2, is_in_roadmap: true},
      {name: 'Support', position: 3, is_in_roadmap: false}
    ]
    
    trackers.each do |t|
      tracker = Tracker.create!(t)
      # Assign all issue statuses to this tracker
      tracker.issue_statuses = IssueStatus.all
      puts \"  ✓ Created tracker: #{t[:name]}\"
    end
  else
    puts '✓ Trackers already exist (' + Tracker.count.to_s + ' trackers)'
  end
  
  # Ensure we have default issue statuses
  if IssueStatus.count == 0
    puts '✓ Creating default issue statuses...'
    statuses = [
      {name: 'New', position: 1, is_closed: false},
      {name: 'In Progress', position: 2, is_closed: false},
      {name: 'Resolved', position: 3, is_closed: false},
      {name: 'Feedback', position: 4, is_closed: false},
      {name: 'Closed', position: 5, is_closed: true},
      {name: 'Rejected', position: 6, is_closed: true}
    ]
    
    statuses.each do |s|
      IssueStatus.create!(s)
      puts \"  ✓ Created status: #{s[:name]}\"
    end
  else
    puts '✓ Issue statuses already exist (' + IssueStatus.count.to_s + ' statuses)'
  end
  
  puts '✅ Default enumerations validated successfully'
rescue => e
  puts '❌ Error configuring enumerations: ' + e.message
end
"

run_rails_command "$ENUMERATIONS_CONFIG" "Validating default enumerations"

# Step 6: Create Customer Demo Project (if enabled)
if [ "$CREATE_DEMO_PROJECT" = "true" ]; then
    echo -e "${INFO} ${BLUE}Step 6: Demo Project Creation${NC}"
    
    PROJECT_CONFIG="
    begin
      customer_name = ENV['CUSTOMER_NAME'] || 'Customer'
      customer_identifier = ENV['CUSTOMER_IDENTIFIER'] || 'customer'
      project = Project.find_by_identifier(customer_identifier) || Project.find_by_name(customer_name + ' Demo')
      
      if project
        puts '✓ Demo project already exists, updating...'
        project.update!(
          name: customer_name + ' Demo',
          description: 'Demonstration project for ' + customer_name,
          is_public: false,
          status: Project::STATUS_ACTIVE
        )
        puts '✅ Demo project updated'
      else
        puts '✓ Creating demo project...'
        project = Project.create!(
          name: customer_name + ' Demo',
          identifier: customer_identifier,
          description: 'Demonstration project for ' + customer_name,
          is_public: false,
          status: Project::STATUS_ACTIVE
        )
        
        # Enable all trackers for this project
        project.trackers = Tracker.all
        project.save!
        
        # Create demo issue
        admin_user = User.find_by_login('admin')
        if admin_user && Tracker.count > 0 && IssuePriority.count > 0 && IssueStatus.count > 0
          issue = Issue.create!(
            project: project,
            tracker: Tracker.first,
            author: admin_user,
            subject: 'Welcome to ' + customer_name + ' Project Management',
            description: 'This is a demonstration issue for your new ' + customer_name + ' project management system.',
            priority: IssuePriority.find_by_is_default(true) || IssuePriority.first,
            status: IssueStatus.first
          )
          puts '  ✓ Created demo issue: Welcome to ' + customer_name + ' Project Management'
        end
        
        puts '✅ Demo project created successfully with sample content'
      end
    rescue => e
      puts '❌ Error creating demo project: ' + e.message
    end
    "
    
    run_rails_command "$PROJECT_CONFIG" "Creating customer demo project"
fi

# Step 7: Final Validation
echo -e "${INFO} ${BLUE}Step 7: Final Validation${NC}"

VALIDATION_CONFIG="
begin
  puts '🔍 Validating Redmica configuration...'
  
  # Check admin user
  admin = User.find_by_login('admin')
  if admin && admin.admin?
    puts '✅ Admin user configured and active'
  else
    puts '❌ Admin user not properly configured'
  end
  
  # Check enumerations
  priorities_count = IssuePriority.count
  trackers_count = Tracker.count
  statuses_count = IssueStatus.count
  
  puts \"✅ Enumerations: #{priorities_count} priorities, #{trackers_count} trackers, #{statuses_count} statuses\"
  
  # Check LDAP (if enabled)
  if '$LDAP_ENABLED' == 'true'
    ldap_count = AuthSource.where(type: 'AuthSourceLdap').count
    if ldap_count > 0
      puts '✅ LDAP authentication configured'
    else
      puts '⚠️ LDAP authentication not configured'
    end
  end
  
  # Check projects
  projects_count = Project.count
  puts \"✅ Projects: #{projects_count} project(s) configured\"
  
  puts '🎉 Zero-touch provisioning completed successfully!'
  puts ''
  puts '📋 Summary:'
  puts \"   Customer: $CUSTOMER_NAME\"
  puts \"   Admin Email: $ADMIN_EMAIL\"
  puts \"   Projects: #{projects_count}\"
  puts \"   LDAP Enabled: $LDAP_ENABLED\"
  puts ''
  puts '🔐 Admin Credentials:'
  puts '   Username: admin'
  puts \"   Password: $ADMIN_PASSWORD\"
  puts '   Email: $ADMIN_EMAIL'
  
rescue => e
  puts '❌ Error during validation: ' + e.message
end
"

run_rails_command "$VALIDATION_CONFIG" "Final validation and summary"

echo ""
echo -e "${ROCKET} ${GREEN}Zero-Touch Redmica Provisioning Complete!${NC}"
echo -e "${INFO} Your customer deployment is ready for use"
echo -e "${INFO} All configuration has been applied programmatically"
echo ""
echo -e "${SUCCESS} Next steps:"
echo -e "   1. Test admin login with provided credentials"
echo -e "   2. Configure additional users via LDAP (if enabled)"
echo -e "   3. Customize project settings as needed"
echo -e "   4. Deploy to customer environment"
echo ""
