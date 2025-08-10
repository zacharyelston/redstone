#!/bin/bash
# Complete Zero-Touch Customer Deployment Script
# Deploys and configures a complete Redstone stack for a new SaaS customer
# Following "Built for Clarity" philosophy - simple, repeatable, maintainable

set -e

# Colors and emojis
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

echo -e "${ROCKET} ${BLUE}Zero-Touch Customer Deployment${NC}"
echo -e "${INFO} Complete Redstone stack deployment and configuration"
echo ""

# Check if customer config file is provided
CUSTOMER_CONFIG=${1:-"customer-deployment.env"}

if [ ! -f "$CUSTOMER_CONFIG" ]; then
    echo -e "${FAILURE} Customer configuration file not found: $CUSTOMER_CONFIG"
    echo -e "${INFO} Usage: $0 [customer-config-file]"
    echo -e "${INFO} Example: $0 customers/acme-corp.env"
    echo ""
    echo -e "${INFO} Creating template configuration file..."
    cp templates/customer-deployment.env.template "$CUSTOMER_CONFIG"
    echo -e "${SUCCESS} Template created at: $CUSTOMER_CONFIG"
    echo -e "${WARNING} Please edit the configuration file and run again"
    exit 1
fi

# Load customer configuration
echo -e "${INFO} Loading customer configuration from: $CUSTOMER_CONFIG"
set -a
source "$CUSTOMER_CONFIG"
set +a

# Validate required configuration
if [ -z "$CUSTOMER_NAME" ] || [ -z "$CUSTOMER_IDENTIFIER" ]; then
    echo -e "${FAILURE} Required configuration missing: CUSTOMER_NAME and CUSTOMER_IDENTIFIER"
    exit 1
fi

echo -e "${SUCCESS} Configuration loaded for: $CUSTOMER_NAME"
echo ""

# Generate secure passwords if not provided
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 16)
    echo -e "${INFO} Generated secure admin password"
fi

# Set namespace based on customer identifier
NAMESPACE="redstone-${CUSTOMER_IDENTIFIER}"

echo -e "${INFO} Deployment configuration:"
echo -e "   Customer: $CUSTOMER_NAME"
echo -e "   Identifier: $CUSTOMER_IDENTIFIER"
echo -e "   Namespace: $NAMESPACE"
echo -e "   Admin Email: $ADMIN_EMAIL"
echo -e "   LDAP Enabled: ${LDAP_ENABLED:-true}"
echo ""

# Step 1: Create customer namespace
echo -e "${INFO} ${BLUE}Step 1: Creating Customer Namespace${NC}"
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo -e "${WARNING} Namespace $NAMESPACE already exists"
else
    kubectl create namespace "$NAMESPACE"
    echo -e "${SUCCESS} Created namespace: $NAMESPACE"
fi

# Step 2: Deploy Helm chart with customer-specific values
echo -e "${INFO} ${BLUE}Step 2: Deploying Redstone Stack${NC}"

# Create customer-specific values file
CUSTOMER_VALUES_FILE="customers/${CUSTOMER_IDENTIFIER}-values.yaml"
mkdir -p customers

cat > "$CUSTOMER_VALUES_FILE" <<EOF
# Customer-specific Helm values for $CUSTOMER_NAME
global:
  customerName: "$CUSTOMER_NAME"
  customerIdentifier: "$CUSTOMER_IDENTIFIER"
  namespace: "$NAMESPACE"

redmica:
  image:
    repository: redmica
    tag: local
  
  environment:
    CUSTOMER_NAME: "$CUSTOMER_NAME"
    CUSTOMER_IDENTIFIER: "$CUSTOMER_IDENTIFIER"
    ADMIN_EMAIL: "$ADMIN_EMAIL"
    DEFAULT_LANGUAGE: "${DEFAULT_LANGUAGE:-en}"
    TIMEZONE: "${TIMEZONE:-UTC}"
    
  persistence:
    enabled: true
    size: 10Gi
    
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

postgresql:
  enabled: true
  auth:
    database: "redmica_${CUSTOMER_IDENTIFIER}"
    username: "redmica"
    password: "$(openssl rand -base64 16)"
    
  persistence:
    enabled: true
    size: 20Gi

ldap:
  enabled: ${LDAP_ENABLED:-true}
  domain: "${LDAP_DOMAIN:-${CUSTOMER_IDENTIFIER}.local}"
  baseDn: "${LDAP_BASE_DN:-dc=${CUSTOMER_IDENTIFIER},dc=local}"
  
grafana:
  enabled: true
  adminPassword: "$(openssl rand -base64 12)"
  
  dashboards:
    default:
      redstone-customer:
        gnetId: 1
        revision: 1
        datasource: prometheus

prometheus:
  enabled: true
  
loki:
  enabled: true
  
fluent-bit:
  enabled: true
EOF

echo -e "${SUCCESS} Created customer values file: $CUSTOMER_VALUES_FILE"

# Deploy with Helm
echo -e "${INFO} Deploying Helm chart..."
cd helm/redstone
helm install "redstone-${CUSTOMER_IDENTIFIER}" . \
    --namespace "$NAMESPACE" \
    --values "../../$CUSTOMER_VALUES_FILE" \
    --wait --timeout=600s

echo -e "${SUCCESS} Helm deployment completed"
cd ../..

# Step 3: Wait for all pods to be ready
echo -e "${INFO} ${BLUE}Step 3: Waiting for Services${NC}"
echo -e "${INFO} Waiting for all pods to be ready..."

kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=600s
echo -e "${SUCCESS} All pods are ready"

# Step 4: Run zero-touch Redmica provisioning
echo -e "${INFO} ${BLUE}Step 4: Configuring Redmica${NC}"

# Export configuration for the provisioning script
export NAMESPACE="$NAMESPACE"
export CUSTOMER_NAME="$CUSTOMER_NAME"
export CUSTOMER_IDENTIFIER="$CUSTOMER_IDENTIFIER"
export ADMIN_EMAIL="$ADMIN_EMAIL"
export ADMIN_PASSWORD="$ADMIN_PASSWORD"
export LDAP_ENABLED="${LDAP_ENABLED:-true}"
export CREATE_DEMO_PROJECT="${CREATE_DEMO_PROJECT:-true}"

# Run the zero-touch provisioning
./scripts/provision-redmica-zero-touch.sh

# Step 5: Run validation tests
echo -e "${INFO} ${BLUE}Step 5: Validation Testing${NC}"
export NAMESPACE="$NAMESPACE"
./scripts/test-redstone-deployment.sh

# Step 6: Generate customer deployment report
echo -e "${INFO} ${BLUE}Step 6: Generating Deployment Report${NC}"

REPORT_FILE="customers/${CUSTOMER_IDENTIFIER}-deployment-report.md"

cat > "$REPORT_FILE" <<EOF
# $CUSTOMER_NAME - Redstone Deployment Report

**Deployment Date:** $(date)
**Customer:** $CUSTOMER_NAME
**Identifier:** $CUSTOMER_IDENTIFIER
**Namespace:** $NAMESPACE

## Access Information

### Admin Access
- **Username:** admin
- **Email:** $ADMIN_EMAIL
- **Password:** $ADMIN_PASSWORD

### Service URLs (via port-forward)
- **Redmica:** http://localhost:3001 (kubectl port-forward svc/redmica 3001:3000 -n $NAMESPACE)
- **Grafana:** http://localhost:3000 (kubectl port-forward svc/redstone-grafana 3000:3000 -n $NAMESPACE)
- **LDAP Admin:** http://localhost:17170 (kubectl port-forward svc/redstone-ldap 17170:17170 -n $NAMESPACE)

## Configuration Summary

### Features Enabled
- **LDAP Authentication:** ${LDAP_ENABLED:-true}
- **Demo Project:** ${CREATE_DEMO_PROJECT:-true}
- **REST API:** ${ENABLE_REST_API:-true}
- **Monitoring:** Grafana + Prometheus + Loki
- **Log Aggregation:** Fluent Bit

### Database
- **Type:** PostgreSQL
- **Database:** redmica_${CUSTOMER_IDENTIFIER}
- **Persistence:** Enabled (20Gi)

### Storage
- **Redmica Data:** Persistent (10Gi)
- **Attachments:** Stored in persistent volume
- **Max Attachment Size:** ${MAX_ATTACHMENT_SIZE:-5120} KB

## Operational Commands

### Access Services
\`\`\`bash
# Access Redmica
kubectl port-forward svc/redmica 3001:3000 -n $NAMESPACE

# Access Grafana
kubectl port-forward svc/redstone-grafana 3000:3000 -n $NAMESPACE

# Access LDAP Admin
kubectl port-forward svc/redstone-ldap 17170:17170 -n $NAMESPACE
\`\`\`

### Monitoring
\`\`\`bash
# Check pod status
kubectl get pods -n $NAMESPACE

# View logs
kubectl logs -f deployment/redmica -n $NAMESPACE

# Run health check
./scripts/test-redstone-deployment.sh
\`\`\`

### Backup & Maintenance
\`\`\`bash
# Database backup
kubectl exec deployment/redstone-postgresql-custom -n $NAMESPACE -- pg_dump -U redmica redmica_${CUSTOMER_IDENTIFIER} > backup.sql

# Update deployment
helm upgrade redstone-${CUSTOMER_IDENTIFIER} ./helm/redstone --namespace $NAMESPACE --values $CUSTOMER_VALUES_FILE
\`\`\`

## Support Information

- **Deployment Script:** deploy-customer-zero-touch.sh
- **Configuration File:** $CUSTOMER_CONFIG
- **Values File:** $CUSTOMER_VALUES_FILE
- **Test Suite:** test-redstone-deployment.sh

---
*This deployment was created using Redstone's zero-touch provisioning system.*
EOF

echo -e "${SUCCESS} Deployment report created: $REPORT_FILE"

# Final summary
echo ""
echo -e "${ROCKET} ${GREEN}Zero-Touch Customer Deployment Complete!${NC}"
echo ""
echo -e "${SUCCESS} Customer: $CUSTOMER_NAME"
echo -e "${SUCCESS} Namespace: $NAMESPACE"
echo -e "${SUCCESS} Admin Email: $ADMIN_EMAIL"
echo -e "${SUCCESS} Admin Password: $ADMIN_PASSWORD"
echo ""
echo -e "${INFO} Next steps:"
echo -e "   1. Review deployment report: $REPORT_FILE"
echo -e "   2. Set up port-forwards to access services"
echo -e "   3. Test admin login and LDAP authentication"
echo -e "   4. Configure DNS/ingress for production access"
echo -e "   5. Set up monitoring alerts and backups"
echo ""
echo -e "${SUCCESS} Your customer deployment is ready for production use!"
