#!/bin/bash

# Redstone Release.com Deployment Testing Script
# Following the "Built for Clarity" design philosophy
# Comprehensive automated testing for Release.com deployments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
TIMEOUT=300  # 5 minutes timeout for tests
RETRY_COUNT=3
RETRY_DELAY=10

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to show usage
show_usage() {
    cat << EOF
Redstone Release.com Deployment Testing

Usage: $0 <environment> [options]

Environments:
  development              Test development environment
  staging                  Test staging environment  
  production               Test production environment
  all                      Test all environments

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  -t, --timeout <seconds> Test timeout (default: 300)
  -r, --retries <count>   Retry count for failed tests (default: 3)
  --skip-load             Skip load testing
  --skip-security         Skip security testing
  --report-file <file>    Save test report to file

Examples:
  $0 development                      # Test development environment
  $0 staging --verbose                # Test staging with verbose output
  $0 production --timeout 600         # Test production with 10min timeout
  $0 all --report-file test-report.json # Test all envs and save report

EOF
}

# Function to get environment URL
get_environment_url() {
    local env=$1
    case $env in
        development)
            echo "https://dev.redstone.example.com"
            ;;
        staging)
            echo "https://staging.redstone.example.com"
            ;;
        production)
            echo "https://redstone.example.com"
            ;;
        *)
            print_error "Unknown environment: $env"
            exit 1
            ;;
    esac
}

# Function to test HTTP endpoint with retries
test_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local description=$3
    local retries=$RETRY_COUNT
    
    print_status "Testing: $description"
    print_status "URL: $url"
    
    while [[ $retries -gt 0 ]]; do
        if curl -f -s -o /dev/null -w "%{http_code}" --max-time 30 "$url" | grep -q "$expected_status"; then
            print_success "✅ $description - HTTP $expected_status"
            return 0
        else
            retries=$((retries - 1))
            if [[ $retries -gt 0 ]]; then
                print_warning "⚠️ Retrying in $RETRY_DELAY seconds... ($retries attempts left)"
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    print_error "❌ $description - Failed after $RETRY_COUNT attempts"
    return 1
}

# Function to test application health
test_application_health() {
    local base_url=$1
    local env=$2
    local test_results=()
    
    print_status "=== Testing Application Health for $env ==="
    
    # Test main application
    if test_endpoint "$base_url/" 200 "Main application endpoint"; then
        test_results+=("app_main:PASS")
    else
        test_results+=("app_main:FAIL")
    fi
    
    # Test health endpoint (if available)
    if test_endpoint "$base_url/health" 200 "Health check endpoint"; then
        test_results+=("app_health:PASS")
    else
        test_results+=("app_health:WARN")  # Health endpoint might not exist
    fi
    
    # Test Redmica login page
    if test_endpoint "$base_url/login" 200 "Redmica login page"; then
        test_results+=("redmica_login:PASS")
    else
        test_results+=("redmica_login:FAIL")
    fi
    
    # Test API endpoints
    if test_endpoint "$base_url/issues.json" 200 "Redmica API endpoint"; then
        test_results+=("redmica_api:PASS")
    else
        test_results+=("redmica_api:FAIL")
    fi
    
    echo "${test_results[@]}"
}

# Function to test monitoring stack
test_monitoring_stack() {
    local base_url=$1
    local env=$2
    local test_results=()
    
    print_status "=== Testing Monitoring Stack for $env ==="
    
    # Test Grafana
    local grafana_url
    case $env in
        development)
            grafana_url="https://dev-grafana.redstone.example.com"
            ;;
        staging)
            grafana_url="https://staging-grafana.redstone.example.com"
            ;;
        production)
            grafana_url="https://grafana.redstone.example.com"
            ;;
    esac
    
    if test_endpoint "$grafana_url/api/health" 200 "Grafana health endpoint"; then
        test_results+=("grafana_health:PASS")
    else
        test_results+=("grafana_health:FAIL")
    fi
    
    if test_endpoint "$grafana_url/login" 200 "Grafana login page"; then
        test_results+=("grafana_login:PASS")
    else
        test_results+=("grafana_login:FAIL")
    fi
    
    echo "${test_results[@]}"
}

# Function to test security headers
test_security_headers() {
    local base_url=$1
    local env=$2
    local test_results=()
    
    print_status "=== Testing Security Headers for $env ==="
    
    # Test for security headers
    local headers=$(curl -s -I "$base_url/" --max-time 30)
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        print_success "✅ X-Frame-Options header present"
        test_results+=("security_xframe:PASS")
    else
        print_warning "⚠️ X-Frame-Options header missing"
        test_results+=("security_xframe:WARN")
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        print_success "✅ X-Content-Type-Options header present"
        test_results+=("security_xcontent:PASS")
    else
        print_warning "⚠️ X-Content-Type-Options header missing"
        test_results+=("security_xcontent:WARN")
    fi
    
    if echo "$headers" | grep -qi "strict-transport-security"; then
        print_success "✅ HSTS header present"
        test_results+=("security_hsts:PASS")
    else
        print_warning "⚠️ HSTS header missing"
        test_results+=("security_hsts:WARN")
    fi
    
    echo "${test_results[@]}"
}

# Function to test load performance
test_load_performance() {
    local base_url=$1
    local env=$2
    local test_results=()
    
    print_status "=== Testing Load Performance for $env ==="
    
    # Simple load test with curl
    local start_time=$(date +%s)
    local concurrent_requests=5
    local total_requests=20
    local success_count=0
    
    print_status "Running $total_requests requests with $concurrent_requests concurrent connections..."
    
    for i in $(seq 1 $concurrent_requests); do
        for j in $(seq 1 $((total_requests / concurrent_requests))); do
            if curl -f -s -o /dev/null --max-time 30 "$base_url/" &; then
                ((success_count++)) || true
            fi
        done
    done
    
    wait  # Wait for all background requests to complete
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local success_rate=$((success_count * 100 / total_requests))
    
    print_status "Load test completed in ${duration}s"
    print_status "Success rate: ${success_rate}% (${success_count}/${total_requests})"
    
    if [[ $success_rate -ge 90 ]]; then
        print_success "✅ Load test passed (${success_rate}% success rate)"
        test_results+=("load_test:PASS")
    else
        print_error "❌ Load test failed (${success_rate}% success rate)"
        test_results+=("load_test:FAIL")
    fi
    
    echo "${test_results[@]}"
}

# Function to run comprehensive tests for environment
test_environment() {
    local env=$1
    local base_url=$(get_environment_url "$env")
    local all_results=()
    
    print_status "🚀 Starting comprehensive testing for $env environment"
    print_status "Base URL: $base_url"
    echo
    
    # Test application health
    local app_results=($(test_application_health "$base_url" "$env"))
    all_results+=("${app_results[@]}")
    echo
    
    # Test monitoring stack
    local monitoring_results=($(test_monitoring_stack "$base_url" "$env"))
    all_results+=("${monitoring_results[@]}")
    echo
    
    # Test security headers (unless skipped)
    if [[ "$SKIP_SECURITY" != "true" ]]; then
        local security_results=($(test_security_headers "$base_url" "$env"))
        all_results+=("${security_results[@]}")
        echo
    fi
    
    # Test load performance (unless skipped)
    if [[ "$SKIP_LOAD" != "true" ]]; then
        local load_results=($(test_load_performance "$base_url" "$env"))
        all_results+=("${load_results[@]}")
        echo
    fi
    
    # Generate summary
    generate_test_summary "$env" "${all_results[@]}"
}

# Function to generate test summary
generate_test_summary() {
    local env=$1
    shift
    local results=("$@")
    
    local pass_count=0
    local fail_count=0
    local warn_count=0
    
    print_status "=== Test Summary for $env Environment ==="
    
    for result in "${results[@]}"; do
        local test_name=$(echo "$result" | cut -d: -f1)
        local test_status=$(echo "$result" | cut -d: -f2)
        
        case $test_status in
            PASS)
                print_success "✅ $test_name"
                ((pass_count++))
                ;;
            FAIL)
                print_error "❌ $test_name"
                ((fail_count++))
                ;;
            WARN)
                print_warning "⚠️ $test_name"
                ((warn_count++))
                ;;
        esac
    done
    
    echo
    print_status "Results: $pass_count passed, $fail_count failed, $warn_count warnings"
    
    # Save to report file if specified
    if [[ -n "$REPORT_FILE" ]]; then
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        cat >> "$REPORT_FILE" << EOF
{
  "environment": "$env",
  "timestamp": "$timestamp",
  "summary": {
    "passed": $pass_count,
    "failed": $fail_count,
    "warnings": $warn_count
  },
  "results": [
$(for result in "${results[@]}"; do
    local test_name=$(echo "$result" | cut -d: -f1)
    local test_status=$(echo "$result" | cut -d: -f2)
    echo "    {\"test\": \"$test_name\", \"status\": \"$test_status\"}"
done | paste -sd, -)
  ]
}
EOF
    fi
    
    # Return exit code based on failures
    if [[ $fail_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Main function
main() {
    local environment=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -t|--timeout)
                TIMEOUT=$2
                shift 2
                ;;
            -r|--retries)
                RETRY_COUNT=$2
                shift 2
                ;;
            --skip-load)
                SKIP_LOAD=true
                shift
                ;;
            --skip-security)
                SKIP_SECURITY=true
                shift
                ;;
            --report-file)
                REPORT_FILE=$2
                shift 2
                ;;
            development|staging|production|all)
                environment=$1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$environment" ]]; then
        print_error "Environment is required"
        show_usage
        exit 1
    fi
    
    # Initialize report file if specified
    if [[ -n "$REPORT_FILE" ]]; then
        echo "[]" > "$REPORT_FILE"
        print_status "Test report will be saved to: $REPORT_FILE"
    fi
    
    # Run tests
    if [[ "$environment" == "all" ]]; then
        local overall_success=true
        for env in development staging production; do
            print_status "🔄 Testing $env environment..."
            if ! test_environment "$env"; then
                overall_success=false
            fi
            echo "=================================="
            echo
        done
        
        if [[ "$overall_success" == "true" ]]; then
            print_success "🎉 All environment tests completed successfully!"
            exit 0
        else
            print_error "💥 Some environment tests failed!"
            exit 1
        fi
    else
        test_environment "$environment"
    fi
}

# Run main function with all arguments
main "$@"
