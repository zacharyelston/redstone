# Redmine Seeds using Rails conventions
# This file should contain all the record creation needed to seed the database with its default values.

# Create default trackers
trackers_data = [
  { name: "Bug", description: "Software defects and issues", default_status_id: 1, is_in_roadmap: false },
  { name: "Feature", description: "New functionality to be developed", default_status_id: 1, is_in_roadmap: true },
  { name: "Support", description: "Assistance and troubleshooting requests", default_status_id: 1, is_in_roadmap: false },
  { name: "Epic", description: "Large feature that contains multiple stories", default_status_id: 1, is_in_roadmap: true },
  { name: "Story", description: "User story that delivers specific business value", default_status_id: 1, is_in_roadmap: true },
  { name: "Task", description: "General work items", default_status_id: 1, is_in_roadmap: true }
]

trackers_data.each_with_index do |tracker_attrs, index|
  Tracker.find_or_create_by(name: tracker_attrs[:name]) do |tracker|
    tracker.description = tracker_attrs[:description]
    tracker.default_status_id = tracker_attrs[:default_status_id]
    tracker.is_in_roadmap = tracker_attrs[:is_in_roadmap]
    tracker.position = index + 1
  end
end

# Create default issue statuses
statuses_data = [
  { name: "New", is_closed: false, is_default: true },
  { name: "In Progress", is_closed: false, is_default: false },
  { name: "Resolved", is_closed: false, is_default: false },
  { name: "Feedback", is_closed: false, is_default: false },
  { name: "Closed", is_closed: true, is_default: false },
  { name: "Rejected", is_closed: true, is_default: false }
]

statuses_data.each_with_index do |status_attrs, index|
  IssueStatus.find_or_create_by(name: status_attrs[:name]) do |status|
    status.is_closed = status_attrs[:is_closed]
    status.is_default = status_attrs[:is_default]
    status.position = index + 1
  end
end

# Create default priorities
priorities_data = [
  { name: "Low", is_default: false, active: true },
  { name: "Normal", is_default: true, active: true },
  { name: "High", is_default: false, active: true },
  { name: "Urgent", is_default: false, active: true },
  { name: "Immediate", is_default: false, active: true }
]

priorities_data.each_with_index do |priority_attrs, index|
  IssuePriority.find_or_create_by(name: priority_attrs[:name]) do |priority|
    priority.is_default = priority_attrs[:is_default]
    priority.active = priority_attrs[:active]
    priority.position = index + 1
  end
end

puts "Seeded default Redmine data successfully"
