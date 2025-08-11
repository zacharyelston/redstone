# Redstone - Zero-Touch SaaS Deployment Platform

A production-ready, zero-touch SaaS deployment platform for Redmica project management, built with Kubernetes and following the "Built for Clarity" design philosophy.

## Overview

Redstone provides **complete zero-touch customer onboarding** for SaaS deployments with:

- ✅ **Zero-touch deployment** - Any customer name (including special characters)
- ✅ **Automated secure credential generation** - OpenSSL-based password creation
- ✅ **Complete infrastructure automation** - Kubernetes + Helm deployment
- ✅ **LDAP authentication integration** - Enterprise-ready user management
- ✅ **Production monitoring stack** - Grafana, Prometheus, Loki logging
- ✅ **Comprehensive validation testing** - Automated deployment verification

Built according to the "Built for Clarity" design philosophy, emphasizing simplicity, modularity, and maintainability for scalable SaaS operations.

## Project Structure

```
├── helm/redstone/                    # Kubernetes Helm charts
│   ├── templates/                    # Kubernetes deployment templates
│   └── values.yaml                   # Default configuration values
├── scripts/                          # Zero-touch deployment automation
│   ├── deploy-customer-zero-touch.sh # Complete customer deployment
│   ├── provision-redmica-zero-touch.sh # Redmica configuration automation
│   └── test-redstone-deployment.sh   # Comprehensive validation testing
├── templates/                        # Customer configuration templates
│   └── customer-deployment.env.template # Customer setup template
├── customers/                        # Customer-specific configurations (gitignored)
├── components/                       # Application components
│   ├── redmica/                      # Redmica project management
│   ├── ldap/                         # LDAP authentication
│   ├── monitoring/                   # Grafana, Prometheus, Loki
│   └── logging/                      # Fluent Bit log collection
├── docker-compose.yml               # Alternative Docker Compose deployment
└── Taskfile.k8s.yml                # Kubernetes operational tasks
```

## Requirements

### Kubernetes Deployment (Recommended)
- **Minikube** or any Kubernetes cluster
- **Helm 3.x** for chart deployment
- **kubectl** for cluster management
- **Docker** for building images

### Alternative Docker Compose
- **Docker** and **Docker Compose** for local development

## Quick Start - Zero-Touch Customer Deployment

Deploy a complete SaaS customer environment in 3 simple steps:

### 1. Setup Kubernetes Environment
```bash
# Start Minikube (if using local development)
minikube start

# Create namespace
kubectl create namespace redstone
```

### 2. Deploy Customer Environment
```bash
# Copy customer template
cp templates/customer-deployment.env.template customers/my-customer.env

# Edit customer configuration
vim customers/my-customer.env

# Deploy complete stack with zero-touch automation
./scripts/deploy-customer-zero-touch.sh customers/my-customer.env
```

### 3. Access Your Deployment
```bash
# Set up port forwarding
kubectl port-forward -n redstone service/redmica 3000:3000 &
kubectl port-forward -n redstone service/redstone-grafana 3001:3000 &

# Access services
# Redmica: http://localhost:3000 (admin credentials in deployment output)
# Grafana: http://localhost:3001 (admin/admin)
```

## Zero-Touch Features

### Automated Customer Onboarding
- **Any customer name** - Handles special characters (O'Brien's, José's, etc.)
- **Secure credential generation** - Auto-generated passwords with OpenSSL
- **Custom branding** - Customer-specific application titles and settings
- **Demo content** - Sample projects and issues for immediate use

### Enterprise Security
- **LDAP authentication** - Automatic LDAP server setup and configuration
- **Kubernetes secrets** - Secure credential storage and management
- **Namespace isolation** - Complete customer separation
- **Audit trails** - Comprehensive logging and monitoring

### Production Monitoring
- **Grafana dashboards** - Real-time metrics and log visualization
- **Prometheus metrics** - System and application performance monitoring
- **Loki logging** - Centralized log aggregation and search
- **Health checks** - Automated validation and alerting

## Operational Commands

### Using Taskfile (Kubernetes)
```bash
# Deploy stack
task k8s:deploy

# View logs
task k8s:logs

# Run health checks
task k8s:health

# Backup data
task k8s:backup

# Teardown deployment
task k8s:teardown
```

### Manual Kubernetes Operations
```bash
# Deploy Helm chart
helm install redstone helm/redstone --namespace redstone --values helm/redstone/values.yaml

# Run comprehensive tests
./scripts/test-redstone-deployment.sh

# Configure customer (after deployment)
CUSTOMER_NAME="My Company" CUSTOMER_IDENTIFIER="my-company" ./scripts/provision-redmica-zero-touch.sh
```

## LDAP Configuration

Redstone provides a flexible, configuration-based approach for managing LDAP users, groups, and role mappings:

### Default Configuration

The default LDAP structure is defined in `components/ldap/ldap-defaults.yaml` and includes:

- Service accounts for each component (Redmica, Grafana, Loki, etc.)
- Common user roles (admin, developer, viewer)
- Standard groups and permissions
- Role mappings for service integrations

### Customizing LDAP

To customize LDAP for your organization:

1. **Option 1**: Edit `components/ldap/ldap-defaults.yaml` directly
2. **Option 2**: Create a custom configuration at `custom/ldap-config.yaml`

### LDAP Authentication

Redstone provides automated LDAP authentication setup for all components:

- **Port**: LDAP uses port 3890 consistently across all services
- **Automated Configuration**: The deployment process configures LDAP for both Grafana and Redmica
- **Testing**: Run `task test-ldap` to verify LDAP authentication is working properly

#### Default Test Credentials

- **Username**: developer_user
- **Password**: devpassword
- **Groups**: developers, grafana_editors, redmica_users

### Quick Start Deployment

```bash
# Clone the repository
git clone https://github.com/zacharyelston/redstone.git
cd redstone

# Install task (if not already installed)
brew install go-task/tap/go-task

# Create .env file from example
cp .env.example .env

# Deploy the full stack
task deploy

# Access services
# Redmica: http://localhost:3000 (default admin/admin or LDAP credentials)
# Grafana: http://localhost:3002 (LDAP credentials)
# LDAP admin: http://localhost:17170 (admin/admin)
```

The configuration system will automatically detect and use your custom configuration during setup.

### Configuration Format

```yaml
# Example structure (see ldap-defaults.yaml for full reference)
base_config:
  domain: yourdomain.local
  base_dn: dc=yourdomain,dc=local

users:
  - username: example_user
    display_name: Example User
    email: user@example.com
    groups: [developers, project_users]

groups:
  - name: developers
    display_name: Developers
    description: Development team access

role_mappings:
  redmica:
    admin: [administrators]
    developer: [developers]
```

The LDAP configuration is automatically applied during deployment using the scripts in `components/ldap/` and `scripts/configure-ldap.sh`.

## SaaS Customer Deployment Workflow

### Zero-Touch Customer Onboarding

Deploy new SaaS customers with complete automation:

```bash
# 1. Create customer configuration
cp templates/customer-deployment.env.template customers/acme-corp.env
vim customers/acme-corp.env  # Edit customer details

# 2. Deploy complete stack
./scripts/deploy-customer-zero-touch.sh customers/acme-corp.env

# 3. Customer is live with:
# - Custom branding (Acme Corp - Project Management)
# - Secure auto-generated credentials
# - LDAP authentication configured
# - Demo project with sample content
# - Full monitoring stack (Grafana, Prometheus, Loki)
```

### Customer Lifecycle Management

**Deploy → Operate → Teardown**

```bash
# Deploy customer
./scripts/deploy-customer-zero-touch.sh customers/customer.env

# Monitor and validate
./scripts/test-redstone-deployment.sh

# Teardown when needed
helm uninstall redstone -n redstone-customer-namespace
```

### Alternative Deployment Methods

**Release.com Static Environments (Production)**
```bash
# Git tag-based deployment workflow
git push origin main                    # → Auto-deploys to development
git tag v1.2.0-rc.1 && git push origin v1.2.0-rc.1  # → Staging (manual approval)
git tag v1.2.0 && git push origin v1.2.0            # → Production (manual approval)

# Environment management
./scripts/manage-release-environments.sh status      # Check all environments
./scripts/manage-release-environments.sh test staging # Test specific environment
./scripts/test-release-deployment.sh production     # Comprehensive testing
```

**Docker Compose (Development)**
```bash
# Local development with Docker Compose
docker-compose up -d

# Access at http://localhost:3000
```

**Manual Kubernetes Deployment**
```bash
# Deploy Helm chart manually
helm install redstone helm/redstone --namespace redstone --values helm/redstone/values.yaml

# Configure customer manually
CUSTOMER_NAME="My Company" ./scripts/provision-redmica-zero-touch.sh
```

## Design Philosophy

Redstone follows the "Built for Clarity" design philosophy:

- **Simplicity Over Complexity**: Favoring clear, straightforward solutions over clever but complex ones
- **Modular Design**: Breaking the system into independent, focused components
- **Encapsulation**: Hiding internal details through well-defined interfaces
- **SOLID Principles**: Following proven design patterns for maintainability
- **Practical Heuristics**: Using KISS, DRY, and YAGNI as guiding principles
- **Continuous Refinement**: Treating design as an ongoing process

## Documentation & Resources

- [AWS Deployment Wiki](https://redstone.redminecloud.net/projects/redstone/wiki/AWS_Deployment)
- [Issue Tracker](https://redstone.redminecloud.net/projects/redstone/issues)
- [Project Standards](https://redstone.redminecloud.net/projects/redstone/wiki/Standards)

## License

MIT