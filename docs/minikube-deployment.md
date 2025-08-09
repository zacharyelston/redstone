# Redstone Minikube + Helm Deployment

This document describes how to deploy Redstone on Minikube using Helm charts, providing a production-mirroring Kubernetes environment for development and testing.

## Overview

The Minikube deployment provides:
- **Production-like Kubernetes environment** using Minikube
- **Helm charts** for consistent, repeatable deployments
- **Proper service labeling** with `service=` labels for clean Grafana dashboards
- **Fluent Bit log collection** that mirrors production logging architecture
- **Complete monitoring stack** with Loki, Grafana, and Prometheus
- **Ingress configuration** for local development access

## Prerequisites

Before starting, ensure you have the following tools installed:

- **Docker Desktop** or Docker Engine
- **Minikube** (v1.28+)
- **Helm** (v3.10+)
- **kubectl** (v1.28+)

### Installation Commands

```bash
# macOS (using Homebrew)
brew install minikube helm kubectl

# Verify installations
minikube version
helm version
kubectl version --client
```

## Quick Start

1. **Run the setup script:**
   ```bash
   ./scripts/setup-minikube.sh
   ```

2. **Access your services:**
   - Redmica: http://redstone.local
   - Grafana: http://grafana.local (admin/admin123)

## Manual Deployment

If you prefer to deploy manually:

### 1. Start Minikube

```bash
minikube start \
    --cpus=4 \
    --memory=8192 \
    --disk-size=20g \
    --driver=docker \
    --kubernetes-version=v1.28.3

# Enable required addons
minikube addons enable ingress
minikube addons enable ingress-dns
```

### 2. Add Helm Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 3. Deploy Redstone

```bash
# Create namespace
kubectl create namespace redstone

# Deploy using Helm
cd helm/redstone
helm upgrade --install redstone . \
    --namespace redstone \
    --create-namespace \
    --wait \
    --timeout=10m
```

### 4. Configure Local DNS

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Add to /etc/hosts
echo "$MINIKUBE_IP redstone.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP grafana.local" | sudo tee -a /etc/hosts
```

## Architecture

### Services Deployed

| Service | Purpose | Port | Ingress |
|---------|---------|------|---------|
| Redmica | Project Management | 3000 | redstone.local |
| PostgreSQL | Database | 5432 | Internal |
| Redis | Cache | 6379 | Internal |
| LDAP | Authentication | 3890 | Internal |
| Loki | Log Aggregation | 3100 | Internal |
| Grafana | Visualization | 3000 | grafana.local |
| Prometheus | Metrics | 9090 | Internal |
| Fluent Bit | Log Collection | 2020 | Internal |

### Logging Architecture

The Minikube deployment uses a production-mirroring logging setup:

1. **Fluent Bit DaemonSet** collects logs from all pods
2. **Kubernetes metadata enrichment** adds service and component labels
3. **Loki** stores and indexes logs with proper labeling
4. **Grafana** displays logs with clean `service=` labels (no `compose_service`)

### Label Strategy

Unlike Docker Compose, Kubernetes gives us full control over labels:
- **service**: Clean service name (e.g., `redis`, `postgres`, `redmica`)
- **component**: Functional component (e.g., `cache`, `database`, `application`)
- **app.kubernetes.io/name**: Kubernetes standard labels
- **app.kubernetes.io/component**: Kubernetes component labels

## Configuration

### Customizing Values

Edit `helm/redstone/values.yaml` to customize the deployment:

```yaml
# Example: Increase Redmica replicas
redmica:
  replicaCount: 2
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi

# Example: Enable persistent storage
postgresql:
  primary:
    persistence:
      enabled: true
      size: 20Gi
```

### Environment-Specific Values

Create environment-specific values files:

```bash
# Development
helm upgrade --install redstone . \
    --namespace redstone \
    --values values.yaml \
    --values values-dev.yaml

# Production
helm upgrade --install redstone . \
    --namespace redstone \
    --values values.yaml \
    --values values-prod.yaml
```

## Monitoring and Logging

### Accessing Grafana

1. **Via Ingress**: http://grafana.local
2. **Via Port Forward**: 
   ```bash
   kubectl port-forward svc/redstone-grafana 3000:3000 -n redstone
   ```

### Default Credentials

- **Username**: admin
- **Password**: admin123

### Pre-configured Dashboards

The deployment includes dashboards for:
- **Service Logs**: Clean `service=` labels without duplication
- **Application Metrics**: Redmica performance monitoring
- **Infrastructure Metrics**: Kubernetes cluster monitoring

## Troubleshooting

### Common Issues

1. **Services not accessible**:
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check DNS resolution
   nslookup redstone.local
   ```

2. **Pods not starting**:
   ```bash
   # Check pod status
   kubectl get pods -n redstone
   
   # Check pod logs
   kubectl logs -f deployment/redstone-redmica -n redstone
   ```

3. **Storage issues**:
   ```bash
   # Check persistent volumes
   kubectl get pv,pvc -n redstone
   
   # Check storage class
   kubectl get storageclass
   ```

### Useful Commands

```bash
# View all resources
kubectl get all -n redstone

# Check ingress
kubectl get ingress -n redstone

# View logs
kubectl logs -f daemonset/redstone-fluent-bit -n redstone

# Access pod shell
kubectl exec -it deployment/redstone-redmica -n redstone -- /bin/bash

# Port forward services
kubectl port-forward svc/redstone-loki 3100:3100 -n redstone
```

## Cleanup

### Stop Services

```bash
# Delete Helm release
helm uninstall redstone -n redstone

# Delete namespace
kubectl delete namespace redstone
```

### Stop Minikube

```bash
# Stop Minikube
minikube stop

# Delete Minikube (complete cleanup)
minikube delete
```

### Remove DNS Entries

```bash
# Remove from /etc/hosts
sudo sed -i '' '/redstone.local/d' /etc/hosts
sudo sed -i '' '/grafana.local/d' /etc/hosts
```

## Production Considerations

This Minikube setup mirrors production architecture but includes development-friendly defaults:

### Security
- Default passwords (change in production)
- No TLS certificates (add cert-manager in production)
- Permissive RBAC (tighten in production)

### Scalability
- Single replicas (increase in production)
- Local storage (use distributed storage in production)
- Resource limits suitable for development

### Monitoring
- Basic dashboards (extend for production monitoring)
- No alerting rules (add Prometheus alerts in production)
- Local data retention (configure long-term storage in production)

## Next Steps

1. **Test the logging setup** - Verify clean `service=` labels in Grafana
2. **Customize dashboards** - Add application-specific monitoring
3. **Add CI/CD integration** - Automate deployments
4. **Implement GitOps** - Use ArgoCD or Flux for production deployments
