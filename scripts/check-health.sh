#!/bin/bash
set -e

echo "🩺 Checking services health..."

# Function to check if a container is healthy or at least running
check_container_health() {
  local container="$1"
  
  # First check if the container exists and is running
  local running=$(docker inspect --format='{{.State.Running}}' "redstone-$container-1" 2>/dev/null || echo "not found")
  
  if [ "$running" == "not found" ]; then
    echo "❌ $container: Container not found"
    return 1
  elif [ "$running" != "true" ]; then
    echo "❌ $container: Not running"
    return 1
  fi
  
  # Then check for health status if available
  local has_health=$(docker inspect --format='{{if .State.Health}}true{{else}}false{{end}}' "redstone-$container-1")
  
  if [ "$has_health" == "true" ]; then
    local status=$(docker inspect --format='{{.State.Health.Status}}' "redstone-$container-1")
    if [ "$status" == "healthy" ]; then
      echo "✅ $container: Healthy"
      return 0
    else
      echo "⚠️ $container: $status"
      return 1
    fi
  else
    # If no health check is defined but container is running, consider it "running well"
    echo "✅ $container: Running"
    return 0
  fi
}

# Check core services
echo "\nCore Services:"
check_container_health "ldap"
check_container_health "postgres"
check_container_health "redmica"

# Check auxiliary services
echo "\nAuxiliary Services:"
check_container_health "redis"
check_container_health "grafana"
check_container_health "prometheus"
check_container_health "loki"

# Check if Redmica is accessible
echo "\nEndpoint Checks:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q "200"; then
  echo "✅ Redmica Web Interface: Accessible"
else
  echo "❌ Redmica Web Interface: Not accessible"
fi

# Check if Grafana is accessible
if curl -L -s -o /dev/null -w "%{http_code}" http://localhost:3002/login | grep -q "200"; then
  echo "✅ Grafana Web Interface: Accessible"
else
  echo "❌ Grafana Web Interface: Not accessible"
fi

echo "\n🔍 Health check complete"
