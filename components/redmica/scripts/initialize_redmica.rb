#!/usr/bin/env ruby
# Redmica initialization script
# This script loads seed data from YAML and initializes Redmica configuration
# It should be run inside the Redmica container with access to Rails environment

require 'yaml'
require File.expand_path('../../../config/environment', __dir__)

puts "Starting Redmica initialization..."

# Load seed data from YAML file
seed_file = '/etc/redmica/seed_data.yml'
unless File.exist?(seed_file)
  puts "ERROR: Seed file #{seed_file} not found!"
  exit 1
end

puts "Loading seed data from #{seed_file}..."
seed_data = YAML.load_file(seed_file)

# Initialize admin user if not exists
admin = User.find_by_login('admin')
unless admin
  puts "Creating admin user..."
  admin = User.new(
    login: 'admin',
    firstname: 'System',
    lastname: 'Administrator',
    mail: 'admin@example.com',
    admin: true,
    password: 'admin',
    password_confirmation: 'admin',
    must_change_passwd: false
  )
  admin.save!
  puts "✅ Admin user created successfully"
end

# Create trackers
if seed_data['trackers']
  puts "Creating trackers..."
  seed_data['trackers'].each do |t|
    tracker = Tracker.find_by_name(t['name']) || Tracker.new(name: t['name'])
    
    tracker.position = t['position']
    tracker.is_in_roadmap = t['is_in_roadmap']
    tracker.description = t['description']
    
    if tracker.save
      puts "✅ Tracker '#{t['name']}' created/updated successfully"
    else
      puts "❌ Failed to create tracker '#{t['name']}': #{tracker.errors.full_messages.join(', ')}"
    end
  end
end

# Create issue statuses
if seed_data['issue_statuses']
  puts "Creating issue statuses..."
  seed_data['issue_statuses'].each do |s|
    status = IssueStatus.find_by_name(s['name']) || IssueStatus.new(name: s['name'])
    
    status.position = s['position'] 
    status.is_closed = s['is_closed']
    status.is_default = s['is_default']
    
    if status.save
      puts "✅ Issue status '#{s['name']}' created/updated successfully"
    else
      puts "❌ Failed to create issue status '#{s['name']}': #{status.errors.full_messages.join(', ')}"
    end
  end
end

# Create issue priorities (IssuePriority is a type of Enumeration)
if seed_data['issue_priorities']
  puts "Creating issue priorities..."
  seed_data['issue_priorities'].each do |p|
    priority = IssuePriority.find_by_name(p['name']) || IssuePriority.new(name: p['name'])
    
    priority.position = p['position']
    priority.is_default = p['is_default']
    priority.active = p['active']
    
    if priority.save
      puts "✅ Issue priority '#{p['name']}' created/updated successfully"
    else
      puts "❌ Failed to create issue priority '#{p['name']}': #{priority.errors.full_messages.join(', ')}"
    end
  end
end

# Create time entry activities (TimeEntryActivity is a type of Enumeration)
if seed_data['time_entry_activities']
  puts "Creating time entry activities..."
  seed_data['time_entry_activities'].each do |a|
    activity = TimeEntryActivity.find_by_name(a['name']) || TimeEntryActivity.new(name: a['name'])
    
    activity.position = a['position']
    activity.is_default = a['is_default']
    activity.active = a['active'] if a.has_key?('active')
    
    if activity.save
      puts "✅ Time entry activity '#{a['name']}' created/updated successfully"
    else
      puts "❌ Failed to create time entry activity '#{a['name']}': #{activity.errors.full_messages.join(', ')}"
    end
  end
end

# Create document categories (DocumentCategory is a type of Enumeration)
if seed_data['document_categories']
  puts "Creating document categories..."
  seed_data['document_categories'].each do |c|
    category = DocumentCategory.find_by_name(c['name']) || DocumentCategory.new(name: c['name'])
    
    category.position = c['position']
    category.is_default = c['is_default'] if c.has_key?('is_default')
    category.active = c['active'] if c.has_key?('active')
    
    if category.save
      puts "✅ Document category '#{c['name']}' created/updated successfully"
    else
      puts "❌ Failed to create document category '#{c['name']}': #{category.errors.full_messages.join(', ')}"
    end
  end
end

# Create a demo project if none exists
if Project.count == 0
  puts "Creating demo project..."
  project = Project.new(
    name: 'Redstone Demo',
    identifier: 'redstone-demo',
    description: 'A demonstration project for Redstone',
    is_public: true
  )
  
  if project.save
    puts "✅ Demo project created successfully"
  else
    puts "❌ Failed to create demo project: #{project.errors.full_messages.join(', ')}"
  end
end

puts "Redmica initialization completed successfully."
