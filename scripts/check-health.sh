#!/bin/bash
set -e

echo "🩺 Checking services health..."

# Function to check if a container is healthy
check_container_health() {
  local container="$1"
  local status=$(docker inspect --format='{{.State.Health.Status}}' "redstone-$container-1" 2>/dev/null || echo "not found")
  
  if [ "$status" == "healthy" ]; then
    echo "✅ $container: Healthy"
    return 0
  elif [ "$status" == "not found" ]; then
    echo "❌ $container: Container not found"
    return 1
  else
    echo "⚠️ $container: $status"
    return 1
  fi
}

# Check core services
echo "\nCore Services:"
check_container_health "lldap"
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
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/ | grep -q "200"; then
  echo "✅ Grafana Web Interface: Accessible"
else
  echo "❌ Grafana Web Interface: Not accessible"
fi

echo "\n🔍 Health check complete"
