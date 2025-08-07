#!/bin/bash
# Test script for Loki Docker Driver implementation
# This script will:
# 1. Stop all current containers
# 2. Start services with the new Loki Docker driver configuration
# 3. Wait for services to start
# 4. Test if logs appear in Loki with proper service labels
# 5. Display results for each service

set -e  # Exit on any error
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDSTONE_DIR="$(cd "${SCRIPT_DIR}/../../" && pwd)"
SERVICES=("postgres" "redmica" "ldap" "grafana" "prometheus" "loki" "redis")
LOKI_PORT=3100
LOG_CHECK_DELAY=20  # Seconds to wait for logs to appear

echo "=== Loki Docker Driver Test ==="
echo "Script running from: ${SCRIPT_DIR}"
echo "Redstone directory: ${REDSTONE_DIR}"

# Function to check if a service has logs in Loki
check_service_logs() {
    local service=$1
    local since=$(date -u -v-10M '+%Y-%m-%dT%H:%M:%SZ')  # Last 10 minutes
    local query="{service=\"${service}\"}"
    local result=$(curl -s -G --data-urlencode "query=${query}" \
                      --data-urlencode "start=${since}" \
                      --data-urlencode "limit=5" \
                      "http://localhost:${LOKI_PORT}/loki/api/v1/query_range" | jq .)
    
    # Check if there are log entries
    local count=$(echo ${result} | jq '.data.result | length')
    if [ "${count}" -gt "0" ]; then
        echo "✅ ${service}: Logs found in Loki"
        # Display sample log entries
        echo "   Sample log entries:"
        echo ${result} | jq -r '.data.result[0].values[0:2][] | .[1]' | sed 's/^/   | /'
        return 0
    else
        echo "❌ ${service}: No logs found in Loki"
        return 1
    fi
}

# Step 1: Stop all current containers
echo -e "\n=== Stopping current containers ==="
cd "${REDSTONE_DIR}"
docker compose down

# Step 2: Start services with Loki Docker driver configuration
echo -e "\n=== Starting services with Loki Docker driver ==="
cd "${REDSTONE_DIR}"
docker compose -f docker-compose.loki-driver.yml up -d

# Step 3: Wait for services to start
echo -e "\n=== Waiting for services to initialize (${LOG_CHECK_DELAY} seconds) ==="
sleep ${LOG_CHECK_DELAY}

# Step 4: Check Loki is up
echo -e "\n=== Checking Loki API ==="
loki_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${LOKI_PORT}/ready)
if [ "${loki_status}" = "200" ]; then
    echo "✅ Loki API is running and responding"
else
    echo "❌ Loki API is not responding (status: ${loki_status})"
    echo "Try increasing LOG_CHECK_DELAY or check Loki container logs"
    exit 1
fi

# Step 5: Generate some activity in services to ensure logs
echo -e "\n=== Generating activity in services ==="
# Hit the Grafana login page
echo "Accessing Grafana..."
curl -s -o /dev/null http://localhost:3002
# Query PostgreSQL status (through container)
echo "Querying PostgreSQL..."
docker exec $(docker ps -qf "name=postgres") pg_isready
# Query Redis
echo "Pinging Redis..."
docker exec $(docker ps -qf "name=redis") redis-cli ping

# Step 6: Wait a bit for logs to propagate
echo -e "\n=== Waiting for logs to propagate (5 seconds) ==="
sleep 5

# Step 7: Check for logs from each service
echo -e "\n=== Checking for logs from each service ==="
success_count=0
for service in "${SERVICES[@]}"; do
    if check_service_logs "${service}"; then
        ((success_count++))
    fi
done

# Step 8: Summarize results
echo -e "\n=== Summary ==="
echo "${success_count}/${#SERVICES[@]} services have logs in Loki"
if [ "${success_count}" -eq "${#SERVICES[@]}" ]; then
    echo "✅ All services are successfully logging to Loki using the Docker driver!"
else
    echo "⚠️  Some services are not logging to Loki. Check container status and configuration."
    echo "You may need to wait longer for logs to appear or check for errors."
fi

echo -e "\n=== Test Complete ==="
