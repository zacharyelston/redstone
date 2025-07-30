#!/usr/bin/env ruby
# Configure Redmica with default settings using REST API
# This script reads configuration from default-config.yml and applies it to Redmica

require 'yaml'
require 'json'
require 'net/http'
require 'uri'
require 'logger'

# Setup logging
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

CONFIG_FILE = File.join(File.dirname(__FILE__), '..', 'components', 'redmica', 'config', 'default-config.yml')
REDMICA_URL = ENV['REDMICA_URL'] || 'http://localhost:3000'
API_KEY = ENV['REDMICA_ADMIN_API_KEY']

if API_KEY.nil?
  logger.error "REDMICA_ADMIN_API_KEY environment variable not set. Cannot proceed."
  exit 1
end

unless File.exist?(CONFIG_FILE)
  logger.error "Configuration file not found: #{CONFIG_FILE}"
  exit 1
end

# Parse YAML configuration
begin
  config = YAML.load_file(CONFIG_FILE)
  logger.info "Loaded configuration from #{CONFIG_FILE}"
rescue => e
  logger.error "Failed to load configuration: #{e.message}"
  exit 1
end

# Helper method to make API requests
def api_request(path, method = :get, data = nil)
  uri = URI.parse("#{REDMICA_URL}#{path}")
  
  case method
  when :get
    request = Net::HTTP::Get.new(uri)
  when :post
    request = Net::HTTP::Post.new(uri)
    request.body = data.to_json if data
  when :put
    request = Net::HTTP::Put.new(uri)
    request.body = data.to_json if data
  when :delete
    request = Net::HTTP::Delete.new(uri)
  end
  
  request['Content-Type'] = 'application/json'
  request['X-Redmine-API-Key'] = API_KEY
  
  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end
  
  [response.code.to_i, JSON.parse(response.body) rescue response.body]
end

# Configure trackers if defined in configuration
if config['trackers']
  logger.info "Configuring trackers..."
  
  # Get existing trackers
  code, existing_trackers = api_request('/trackers.json')
  if code != 200
    logger.error "Failed to get existing trackers: #{existing_trackers}"
  else
    existing_tracker_names = existing_trackers['trackers'].map { |t| t['name'] }
    
    # Create missing trackers
    config['trackers'].each do |tracker|
      unless existing_tracker_names.include?(tracker['name'])
        logger.info "Creating tracker: #{tracker['name']}"
        code, response = api_request('/trackers.json', :post, {
          tracker: {
            name: tracker['name'],
            default_status_id: 1, # New status
            description: tracker['description']
          }
        })
        
        if code != 201
          logger.error "Failed to create tracker '#{tracker['name']}': #{response}"
        else
          logger.info "Successfully created tracker: #{tracker['name']}"
        end
      else
        logger.info "Tracker '#{tracker['name']}' already exists"
      end
    end
  end
end

# Configure statuses if defined in configuration
if config['statuses']
  logger.info "Configuring issue statuses..."
  # Note: Status creation requires admin rights and may not be supported via API
  # This would typically require direct database access or Redmine plugin
  logger.warn "Status configuration via API is limited and may require manual setup"
  
  # For demo purposes, list existing statuses
  code, statuses = api_request('/issue_statuses.json')
  if code != 200
    logger.error "Failed to get existing issue statuses: #{statuses}"
  else
    existing_status_names = statuses['issue_statuses'].map { |s| s['name'] }
    logger.info "Existing statuses: #{existing_status_names.join(', ')}"
    
    config['statuses'].each do |status|
      if existing_status_names.include?(status['name'])
        logger.info "Status '#{status['name']}' already exists"
      else
        logger.warn "Status '#{status['name']}' is missing but cannot be created via API"
      end
    end
  end
end

logger.info "Configuration complete!"
