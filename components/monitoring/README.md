# Multi-Environment Grafana Configuration

This directory contains auto-configured Grafana setup for seamless deployment across Docker Compose, Minikube, and Kubernetes environments.

## Features

✅ **Environment-agnostic datasource configuration** - Uses environment variables for Prometheus and Loki URLs  
✅ **Automatic dashboard provisioning** - All dashboards loaded from `/etc/grafana/dashboards`  
✅ **Externalized LDAP configuration** - Template-based LDAP config with environment variables  
✅ **Multi-environment compatibility** - Works with Docker Compose, Kubernetes, and local development  

## Quick Start

### Docker Compose
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your specific URLs
# PROMETHEUS_URL=http://prometheus:9090
# LOKI_URL=http://loki:3100

# Deploy
docker-compose -f docker-compose.grafana.yml up -d
```

### Kubernetes
```bash
# Apply ConfigMap and Secrets
kubectl apply -f grafana-configmap.yaml

# Deploy via Helm (values already configured)
helm install redstone ./helm/redstone
```

## Configuration Files

| File | Purpose |
|------|---------|
| `grafana/provisioning/datasources/datasources.yml` | Templated datasource configuration |
| `grafana/provisioning/dashboards/dashboards.yml` | Dashboard provisioning settings |
| `grafana/auth/ldap.toml.template` | LDAP configuration template |
| `grafana-configmap.yaml` | Kubernetes environment configuration |
| `.env.example` | Docker Compose environment template |

## Environment Variables

### Required Variables
- `PROMETHEUS_URL` - Prometheus server endpoint
- `LOKI_URL` - Loki server endpoint
- `GRAFANA_ADMIN_PASSWORD` - Admin user password

### LDAP Variables (Optional)
- `LDAP_HOST` - LDAP server hostname
- `LDAP_PORT` - LDAP server port
- `LDAP_BIND_DN` - LDAP bind DN
- `LDAP_BIND_PASSWORD` - LDAP bind password

## Dashboard Management

All dashboards in `grafana/dashboards/` are automatically:
- Provisioned on startup
- Use standardized datasource UIDs (`prometheus`, `loki`)
- Support live editing in Grafana UI

## Testing

Run the validation script to verify configuration:
```bash
./test-multi-environment.sh
```

## Troubleshooting

### Dashboard Not Loading
- Verify dashboard files are in `grafana/dashboards/`
- Check datasource UIDs match provisioned datasources
- Review Grafana logs for provisioning errors

### LDAP Authentication Issues
- Generate LDAP config: `./grafana/generate-ldap-config.sh`
- Verify environment variables are set correctly
- Test LDAP connectivity from Grafana container

### Environment-Specific Issues
- Docker Compose: Check `.env` file exists and is loaded
- Kubernetes: Verify ConfigMap and Secrets are applied
- Local development: Ensure service names resolve correctly
