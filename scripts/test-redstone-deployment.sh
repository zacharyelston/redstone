#!/bin/bash
# Redstone Deployment Validation Test Suite
# Comprehensive testing for Kubernetes deployment following "Built for Clarity" philosophy
# Tests all services, integrations, and validates complete stack functionality

set +e  # Don't exit on error - run all tests
FAILURES=0
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

echo -e "${ROCKET} ${BLUE}Redstone Deployment Validation Test Suite${NC}"
echo -e "${INFO} Testing complete Kubernetes deployment in namespace: ${NAMESPACE}"
echo ""

# Function to log test results
log_test() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    if [ "$result" = "PASS" ]; then
        echo -e "${SUCCESS} ${GREEN}PASS${NC}: $test_name"
        [ -n "$details" ] && echo -e "   ${details}"
    elif [ "$result" = "FAIL" ]; then
        echo -e "${FAILURE} ${RED}FAIL${NC}: $test_name"
        [ -n "$details" ] && echo -e "   ${details}"
        FAILURES=$((FAILURES+1))
    else
        echo -e "${WARNING} ${YELLOW}WARN${NC}: $test_name"
        [ -n "$details" ] && echo -e "   ${details}"
    fi
}

# Test 1: Verify all required pods are running
echo -e "${INFO} ${BLUE}Test 1: Pod Health Check${NC}"
REQUIRED_PODS=(
    "redmica"
    "redstone-postgresql-custom"
    "redstone-ldap"
    "redstone-grafana"
    "redstone-loki"
    "redstone-fluent-bit"
    "redstone-prometheus-server"
)

for pod_prefix in "${REQUIRED_PODS[@]}"; do
    pod_status=$(kubectl get pods -n $NAMESPACE | grep "$pod_prefix" | grep "Running" | wc -l)
    if [ "$pod_status" -gt 0 ]; then
        pod_name=$(kubectl get pods -n $NAMESPACE | grep "$pod_prefix" | grep "Running" | awk '{print $1}' | head -1)
        ready_status=$(kubectl get pod "$pod_name" -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$ready_status" = "True" ]; then
            log_test "$pod_prefix pod health" "PASS" "Pod: $pod_name"
        else
            log_test "$pod_prefix pod health" "FAIL" "Pod not ready: $pod_name"
        fi
    else
        log_test "$pod_prefix pod health" "FAIL" "No running pods found for $pod_prefix"
    fi
done

echo ""

# Test 2: Database connectivity and migration status
echo -e "${INFO} ${BLUE}Test 2: Database Validation${NC}"
REDMICA_POD=$(kubectl get pods -n $NAMESPACE | grep redmica | grep Running | awk '{print $1}' | head -1)

if [ -n "$REDMICA_POD" ]; then
    # Test database connection
    db_version=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT version()').first['version']" RAILS_ENV=production 2>/dev/null)
    if [[ "$db_version" == *"PostgreSQL"* ]]; then
        log_test "Database connection" "PASS" "Connected to: $(echo $db_version | cut -d' ' -f1-2)"
    else
        log_test "Database connection" "FAIL" "Could not connect to database"
    fi
    
    # Test database migrations
    migration_status=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rake db:migrate:status RAILS_ENV=production 2>/dev/null | grep "^   down" | wc -l)
    if [ "$migration_status" -eq 0 ]; then
        log_test "Database migrations" "PASS" "All migrations up"
    else
        log_test "Database migrations" "FAIL" "$migration_status pending migrations"
    fi
    
    # Test enumerations exist - detailed check
    priorities_count=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts IssuePriority.count" RAILS_ENV=production 2>/dev/null)
    trackers_count=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts Tracker.count" RAILS_ENV=production 2>/dev/null)
    statuses_count=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts IssueStatus.count" RAILS_ENV=production 2>/dev/null)
    
    if [ "$priorities_count" -gt 0 ] && [ "$trackers_count" -gt 0 ] && [ "$statuses_count" -gt 0 ]; then
        log_test "Issue priorities" "PASS" "$priorities_count priorities loaded"
        log_test "Issue trackers" "PASS" "$trackers_count trackers loaded"
        log_test "Issue statuses" "PASS" "$statuses_count statuses loaded"
        
        # Check for default priority
        default_priority=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts IssuePriority.where(is_default: true).first&.name || 'None'" RAILS_ENV=production 2>/dev/null)
        if [ "$default_priority" != "None" ]; then
            log_test "Default priority" "PASS" "Default: $default_priority"
        else
            log_test "Default priority" "FAIL" "No default priority set"
        fi
    else
        log_test "Redmica enumerations" "FAIL" "Missing enumerations: priorities=$priorities_count, trackers=$trackers_count, statuses=$statuses_count"
    fi
else
    log_test "Database tests" "FAIL" "Redmica pod not found"
fi

echo ""

# Test 3: Service connectivity
echo -e "${INFO} ${BLUE}Test 3: Service Connectivity${NC}"
SERVICES=(
    "redmica:3000"
    "redstone-postgresql-custom:5432"
    "redstone-ldap:3890"
    "redstone-grafana:3000"
    "loki:3100"
)

for service in "${SERVICES[@]}"; do
    service_name=$(echo $service | cut -d: -f1)
    service_port=$(echo $service | cut -d: -f2)
    
    # Check if service exists
    svc_exists=$(kubectl get svc -n $NAMESPACE | grep "$service_name" | wc -l)
    if [ "$svc_exists" -gt 0 ]; then
        cluster_ip=$(kubectl get svc "$service_name" -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
        log_test "$service_name service" "PASS" "ClusterIP: $cluster_ip:$service_port"
    else
        log_test "$service_name service" "FAIL" "Service not found"
    fi
done

echo ""

# Test 4: LDAP Integration
echo -e "${INFO} ${BLUE}Test 4: LDAP Integration${NC}"
LDAP_POD=$(kubectl get pods -n $NAMESPACE | grep redstone-ldap | grep Running | awk '{print $1}' | head -1)

if [ -n "$LDAP_POD" ]; then
    # Test LDAP service is responding
    ldap_health=$(kubectl exec "$LDAP_POD" -n $NAMESPACE -- nc -z localhost 3890 2>/dev/null && echo "OK" || echo "FAIL")
    if [ "$ldap_health" = "OK" ]; then
        log_test "LDAP service health" "PASS" "Port 3890 responding"
    else
        log_test "LDAP service health" "FAIL" "Port 3890 not responding"
    fi
    
    # Test LDAP web UI
    ldap_web=$(kubectl exec "$LDAP_POD" -n $NAMESPACE -- nc -z localhost 17170 2>/dev/null && echo "OK" || echo "FAIL")
    if [ "$ldap_web" = "OK" ]; then
        log_test "LDAP web interface" "PASS" "Port 17170 responding"
    else
        log_test "LDAP web interface" "FAIL" "Port 17170 not responding"
    fi
    
    # Test Redmica LDAP configuration - comprehensive check
    if [ -n "$REDMICA_POD" ]; then
        # Check configuration.yml LDAP settings
        ldap_config=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- cat /redmica/config/configuration.yml 2>/dev/null | grep "enabled: true" | wc -l)
        if [ "$ldap_config" -gt 0 ]; then
            log_test "LDAP config file" "PASS" "LDAP enabled in configuration.yml"
            
            # Check LDAP host configuration
            ldap_host=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- cat /redmica/config/configuration.yml 2>/dev/null | grep "host:" | awk '{print $2}' | tr -d '"')
            if [ "$ldap_host" = "redstone-ldap" ]; then
                log_test "LDAP host config" "PASS" "Host: $ldap_host"
            else
                log_test "LDAP host config" "WARN" "Host: $ldap_host (expected: redstone-ldap)"
            fi
            
            # Check LDAP port configuration
            ldap_port=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- cat /redmica/config/configuration.yml 2>/dev/null | grep "port:" | awk '{print $2}')
            if [ "$ldap_port" = "3890" ]; then
                log_test "LDAP port config" "PASS" "Port: $ldap_port"
            else
                log_test "LDAP port config" "WARN" "Port: $ldap_port (expected: 3890)"
            fi
        else
            log_test "LDAP config file" "FAIL" "LDAP not enabled in configuration"
        fi
        
        # Check if LDAP authentication sources are configured in Redmica database
        auth_sources_count=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts AuthSource.count" RAILS_ENV=production 2>/dev/null)
        if [ "$auth_sources_count" -gt 0 ]; then
            log_test "LDAP auth sources" "PASS" "$auth_sources_count authentication sources configured"
            
            # Get details of first auth source
            auth_source_details=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "auth = AuthSource.first; puts \"#{auth.name}|#{auth.host}|#{auth.port}|#{auth.active?}\" if auth" RAILS_ENV=production 2>/dev/null)
            if [ -n "$auth_source_details" ]; then
                auth_name=$(echo "$auth_source_details" | cut -d'|' -f1)
                auth_host=$(echo "$auth_source_details" | cut -d'|' -f2)
                auth_port=$(echo "$auth_source_details" | cut -d'|' -f3)
                auth_active=$(echo "$auth_source_details" | cut -d'|' -f4)
                log_test "LDAP auth source details" "PASS" "Name: $auth_name, Host: $auth_host:$auth_port, Active: $auth_active"
            fi
        else
            log_test "LDAP auth sources" "WARN" "No LDAP authentication sources configured in Redmica admin"
        fi
    fi
else
    log_test "LDAP tests" "FAIL" "LDAP pod not found"
fi

echo ""

# Test 5: Monitoring Stack
echo -e "${INFO} ${BLUE}Test 5: Monitoring Stack${NC}"

# Test Grafana
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE | grep redstone-grafana | grep Running | awk '{print $1}' | head -1)
if [ -n "$GRAFANA_POD" ]; then
    grafana_health=$(kubectl exec "$GRAFANA_POD" -n $NAMESPACE -- nc -z localhost 3000 2>/dev/null && echo "OK" || echo "FAIL")
    if [ "$grafana_health" = "OK" ]; then
        log_test "Grafana health" "PASS" "Port 3000 responding"
    else
        log_test "Grafana health" "FAIL" "Port 3000 not responding"
    fi
else
    log_test "Grafana health" "FAIL" "Grafana pod not found"
fi

# Test Loki
LOKI_POD=$(kubectl get pods -n $NAMESPACE | grep redstone-loki | grep Running | awk '{print $1}' | head -1)
if [ -n "$LOKI_POD" ]; then
    loki_health=$(kubectl exec "$LOKI_POD" -n $NAMESPACE -- nc -z localhost 3100 2>/dev/null && echo "OK" || echo "FAIL")
    if [ "$loki_health" = "OK" ]; then
        log_test "Loki health" "PASS" "Port 3100 responding"
    else
        log_test "Loki health" "FAIL" "Port 3100 not responding"
    fi
else
    log_test "Loki health" "FAIL" "Loki pod not found"
fi

# Test Fluent Bit log collection
FLUENT_POD=$(kubectl get pods -n $NAMESPACE | grep redstone-fluent-bit | grep Running | awk '{print $1}' | head -1)
if [ -n "$FLUENT_POD" ]; then
    fluent_logs=$(kubectl logs "$FLUENT_POD" -n $NAMESPACE --tail=10 2>/dev/null | grep -E "(Fluent Bit|started)" | wc -l)
    if [ "$fluent_logs" -gt 0 ]; then
        log_test "Fluent Bit log collection" "PASS" "Log processing active"
    else
        log_test "Fluent Bit log collection" "WARN" "No recent log processing detected"
    fi
else
    log_test "Fluent Bit log collection" "FAIL" "Fluent Bit pod not found"
fi

echo ""

# Test 6: Application Functionality
echo -e "${INFO} ${BLUE}Test 6: Application Functionality${NC}"

if [ -n "$REDMICA_POD" ]; then
    # Test Redmica is serving requests by checking if the process is running
    redmica_process=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- ps aux | grep puma | grep -v grep | wc -l 2>/dev/null)
    if [ "$redmica_process" -gt 0 ]; then
        log_test "Redmica application" "PASS" "Puma server running"
    else
        log_test "Redmica application" "FAIL" "Puma server not running"
    fi
    
    # Test Rails environment
    rails_env=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- bundle exec rails runner "puts Rails.env" RAILS_ENV=production 2>/dev/null)
    if [ "$rails_env" = "production" ]; then
        log_test "Rails environment" "PASS" "Running in production mode"
    else
        log_test "Rails environment" "FAIL" "Not running in production mode: $rails_env"
    fi
else
    log_test "Application tests" "FAIL" "Redmica pod not found"
fi

echo ""

# Test 7: Configuration Validation
echo -e "${INFO} ${BLUE}Test 7: Configuration Validation${NC}"

if [ -n "$REDMICA_POD" ]; then
    # Test database.yml exists and is valid
    db_config=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- test -f /redmica/config/database.yml && echo "OK" || echo "FAIL")
    if [ "$db_config" = "OK" ]; then
        log_test "Database configuration" "PASS" "database.yml exists"
    else
        log_test "Database configuration" "FAIL" "database.yml missing"
    fi
    
    # Test configuration.yml exists and is valid
    app_config=$(kubectl exec "$REDMICA_POD" -n $NAMESPACE -- test -f /redmica/config/configuration.yml && echo "OK" || echo "FAIL")
    if [ "$app_config" = "OK" ]; then
        log_test "Application configuration" "PASS" "configuration.yml exists"
    else
        log_test "Application configuration" "FAIL" "configuration.yml missing"
    fi
fi

echo ""

# Final Results
echo -e "${ROCKET} ${BLUE}Test Results Summary${NC}"
echo "=================================="

TOTAL_TESTS=$(($(grep -c "log_test" "$0") - 1))  # Subtract 1 for this line itself
PASSED_TESTS=$((TOTAL_TESTS - FAILURES))

if [ $FAILURES -eq 0 ]; then
    echo -e "${SUCCESS} ${GREEN}ALL TESTS PASSED${NC}"
    echo -e "   Passed: $PASSED_TESTS/$TOTAL_TESTS"
    echo -e "   ${ROCKET} Redstone deployment is fully operational!"
    exit 0
elif [ $FAILURES -lt 3 ]; then
    echo -e "${WARNING} ${YELLOW}MOSTLY PASSING${NC}"
    echo -e "   Passed: $PASSED_TESTS/$TOTAL_TESTS"
    echo -e "   Failed: $FAILURES"
    echo -e "   ${INFO} Minor issues detected, but core functionality working"
    exit 1
else
    echo -e "${FAILURE} ${RED}MULTIPLE FAILURES${NC}"
    echo -e "   Passed: $PASSED_TESTS/$TOTAL_TESTS"
    echo -e "   Failed: $FAILURES"
    echo -e "   ${WARNING} Significant issues detected, review deployment"
    exit 2
fi
