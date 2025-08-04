#!/bin/bash
# Redmica initialization script
# Initializes Redmica with trackers and enumerations from seed data
# Uses docker exec to run commands inside the Redmica container

set -e

echo "Starting Redmica initialization..."

# Set Redmica container name
REDMICA_CONTAINER=${REDMICA_CONTAINER:-redmica}
echo "Using Redmica container: $REDMICA_CONTAINER"

# Check if the Redmica container is running
echo "Checking if Redmica container is running..."
if ! docker ps | grep -q "$REDMICA_CONTAINER"; then
  echo "ERROR: Redmica container '$REDMICA_CONTAINER' is not running"
  exit 1
fi

# Check if seed data file exists
if [ ! -f /etc/redmica/seed_data.yml ]; then
  echo "ERROR: Seed data file not found at /etc/redmica/seed_data.yml"
  exit 1
fi

echo "Copying seed data to Redmica container..."
docker cp /etc/redmica/seed_data.yml "$REDMICA_CONTAINER:/tmp/seed_data.yml"

# Function to run Rails commands in the Redmica container
run_in_redmica() {
  docker exec -i "$REDMICA_CONTAINER" bash -c "cd /usr/src/redmine && $1"
}

# Skip admin user creation as it's already handled by Redmica's built-in initialization

# Apply trackers configuration
echo "Configuring trackers..."
run_in_redmica "bundle exec rails runner \"begin
  require 'yaml'
  seed_data = YAML.load_file('/tmp/seed_data.yml')
  
  # First ensure we have at least one status
  default_status = IssueStatus.first
  if !default_status
    default_status = IssueStatus.new(name: 'New', position: 1)
    if default_status.save
      puts '✅ Created default status for trackers'
    else
      puts '❌ Failed to create default status: ' + default_status.errors.full_messages.join(', ')
    end
  end
  
  if seed_data && seed_data['trackers']
    seed_data['trackers'].each do |t|
      tracker = Tracker.find_by_name(t['name']) || Tracker.new(name: t['name'])
      tracker.position = t['position'] || 1
      tracker.is_in_roadmap = t['is_in_roadmap'].nil? ? true : t['is_in_roadmap']
      tracker.description = t['description'] || ''
      
      # Set default status
      if !tracker.default_status
        tracker.default_status = default_status
      end
      
      if tracker.save
        puts '✅ Tracker created/updated: ' + t['name']
      else
        puts '❌ Failed to save tracker: ' + tracker.errors.full_messages.join(', ')
      end
    end
  else
    puts '❌ No trackers found in seed data'
  end
rescue => e
  puts '❌ Error loading trackers: ' + e.message
end\""


# Apply enumerations configuration
echo "Configuring enumerations..."

# Issue priorities
echo "Setting up issue priorities..."
run_in_redmica "bundle exec rails runner \"begin
  require 'yaml'
  seed_data = YAML.load_file('/tmp/seed_data.yml')
  if seed_data && seed_data['issue_priorities']
    seed_data['issue_priorities'].each do |p|
      priority = IssuePriority.find_by_name(p['name']) || IssuePriority.new(name: p['name'])
      priority.position = p['position'] || 1
      priority.is_default = p['is_default'] || false
      priority.active = p['active'].nil? ? true : p['active']
      
      if priority.save
        puts '✅ Issue priority created/updated: ' + p['name']
      else
        puts '❌ Failed to save issue priority ' + p['name'] + ': ' + priority.errors.full_messages.join(', ')
      end
    end
  else
    puts '❌ No issue priorities found in seed data'
  end
rescue => e
  puts '❌ Error loading issue priorities: ' + e.message
end\""

# Issue statuses
echo "Setting up issue statuses..."
run_in_redmica "bundle exec rails runner \"begin
  require 'yaml'
  seed_data = YAML.load_file('/tmp/seed_data.yml')
  if seed_data && seed_data['issue_statuses']
    seed_data['issue_statuses'].each do |s|
      status = IssueStatus.find_by_name(s['name']) || IssueStatus.new(name: s['name'])
      status.position = s['position'] || 1
      status.is_closed = s['is_closed'] || false
      # Removed is_default as it's not supported by the IssueStatus model
      
      if status.save
        puts '✅ Issue status created/updated: ' + s['name']
      else
        puts '❌ Failed to save issue status ' + s['name'] + ': ' + status.errors.full_messages.join(', ')
      end
    end
  else
    puts '❌ No issue statuses found in seed data'
  end
rescue => e
  puts '❌ Error loading issue statuses: ' + e.message
end\""

# Time entry activities
echo "Setting up time entry activities..."
run_in_redmica "bundle exec rails runner \"begin
  require 'yaml'
  seed_data = YAML.load_file('/tmp/seed_data.yml')
  if seed_data && seed_data['time_entry_activities']
    seed_data['time_entry_activities'].each do |a|
      activity = TimeEntryActivity.find_by_name(a['name']) || TimeEntryActivity.new(name: a['name'])
      activity.position = a['position'] || 1
      activity.is_default = a['is_default'] || false
      activity.active = a['active'].nil? ? true : a['active']
      
      if activity.save
        puts '✅ Time entry activity created/updated: ' + a['name']
      else
        puts '❌ Failed to save time entry activity ' + a['name'] + ': ' + activity.errors.full_messages.join(', ')
      end
    end
  else
    puts '❌ No time entry activities found in seed data'
  end
rescue => e
  puts '❌ Error loading time entry activities: ' + e.message
end\""

# Document categories
echo "Setting up document categories..."
run_in_redmica "bundle exec rails runner \"begin
  require 'yaml'
  seed_data = YAML.load_file('/tmp/seed_data.yml')
  if seed_data && seed_data['document_categories']
    seed_data['document_categories'].each do |c|
      category = DocumentCategory.find_by_name(c['name']) || DocumentCategory.new(name: c['name'])
      category.position = c['position'] || 1
      category.is_default = c['is_default'] || false
      category.active = c['active'].nil? ? true : c['active']
      
      if category.save
        puts '✅ Document category created/updated: ' + c['name']
      else
        puts '❌ Failed to save document category ' + c['name'] + ': ' + category.errors.full_messages.join(', ')
      end
    end
  else
    puts '❌ No document categories found in seed data'
  end
rescue => e
  puts '❌ Error loading document categories: ' + e.message
end\""

# Create demo project if none exists
echo "Creating demo project if needed..."
run_in_redmica "bundle exec rails runner \"begin
  if Project.count == 0
    project = Project.new(
      name: 'Redstone Demo',
      identifier: 'redstone-demo',
      description: 'A demonstration project for Redstone',
      is_public: true
    )
    
    if project.save
      puts '✅ Demo project created successfully'
    else
      puts '❌ Failed to create demo project: ' + project.errors.full_messages.join(', ')
    end
  else
    puts '✓ Projects already exist, skipping demo project creation'
  end
rescue => e
  puts '❌ Error creating demo project: ' + e.message
end\""

echo "Redmica initialization completed successfully."
