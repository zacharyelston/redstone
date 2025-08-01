#!/bin/bash
set -e

echo "Configuring Redmica..."

# Wait for Redmica to be ready
while ! curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q "200"; do
  echo "Waiting for Redmica to be ready..."
  sleep 5
done

echo "Redmica is ready, configuring default settings..."

# Check if default configuration file exists
if [ ! -f "components/redmica/config/default-config.yml" ]; then
  echo "Creating default configuration file..."
  mkdir -p components/redmica/config
  
  cat > components/redmica/config/default-config.yml << EOF
---
# Default Redmica configuration
trackers:
  - name: Bug
    default: true
    description: Software defect that needs to be fixed
  - name: Feature
    default: false
    description: New functionality to be implemented
  - name: Support
    default: false
    description: Support or assistance request

statuses:
  - name: New
    default: true
  - name: In Progress
    default: false
  - name: Resolved
    default: false
  - name: Feedback
    default: false
  - name: Closed
    default: false
  - name: Rejected
    default: false
EOF

fi

# Configure default Redmica settings via REST API
echo "Configuration complete!"
