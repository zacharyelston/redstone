# Release.com ClusterRole Conflict Debugging Guide

## Problem Description
ClusterRole conflicts occur in Release.com ephemeral environments when multiple deployments try to create the same cluster-scoped resources. The error typically looks like:

```
Error: Unable to continue with install: ClusterRole "redstone-loki-grafana-agent" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: key "meta.helm.sh/release-name" must equal "redstone": current value is "previous-release"
```

## Root Cause
- ClusterRoles are cluster-scoped (not namespaced)
- Multiple ephemeral environments share the same cluster
- Helm tracks resource ownership via annotations
- Different release names conflict when trying to manage the same ClusterRole

## Debugging with Release CLI

### 1. Check Current Deployments
```bash
# List all apps in your account
release apps list

# Get specific app details
release apps get <app-name>

# Check deployment status
release deploys list --app <app-name>
```

### 2. Inspect Environment Details
```bash
# List environments for the app
release environments list --app <app-name>

# Get specific environment details
release environments get <environment-id>

# Check if environment is still running
release instances list --environment <environment-id>
```

### 3. Debug ClusterRole Conflicts
```bash
# Check for existing ClusterRoles (if you have cluster access)
kubectl get clusterroles | grep -E "(loki|grafana|prometheus)"

# Check Helm releases in the cluster
helm list --all-namespaces | grep redstone

# Inspect specific release
helm get values <release-name> -n <namespace>
```

### 4. Clean Up Conflicting Resources
```bash
# Delete specific ClusterRole (if accessible)
kubectl delete clusterrole redstone-loki-grafana-agent

# Or delete the entire conflicting Helm release
helm uninstall <conflicting-release-name> -n <namespace>
```

## Solution: ClusterRole-Free Configuration

Our Helm chart has been updated to completely disable all ClusterRole-creating components:

### Loki Configuration
```yaml
loki:
  monitoring:
    enabled: false
  grafana-agent-operator:
    enabled: false
  serviceMonitor:
    enabled: false
  prometheusRule:
    enabled: false
  rbac:
    create: false
  grafanaAgent:
    enabled: false
  agent:
    enabled: false
```

### Grafana Configuration
```yaml
grafana:
  rbac:
    create: false
    namespaced: true
  sidecar:
    dashboards:
      enabled: false
    datasources:
      enabled: false
    alerts:
      enabled: false
    notifiers:
      enabled: false
  agent:
    enabled: false
  grafana-agent-operator:
    enabled: false
  grafanaOperator:
    enabled: false
  grafanaAgent:
    enabled: false
```

### Prometheus Configuration
```yaml
prometheus:
  kube-state-metrics:
    enabled: false
  rbac:
    create: false
  server:
    rbac:
      create: false
    clusterRole: false
  serviceMonitor:
    enabled: false
  prometheusRule:
    enabled: false
```

## Verification Steps

### 1. Test Locally First
```bash
# Lint the chart
helm lint ./helm/redstone

# Dry run to check for ClusterRole creation
helm install test-release ./helm/redstone --dry-run --debug | grep -i clusterrole

# Should return no results if properly configured
```

### 2. Deploy to Release.com
```bash
# Push changes to your branch
git add .
git commit -m "fix: disable all ClusterRole-creating components for Release.com compatibility"
git push origin <your-branch>

# Deploy via Release.com UI or trigger deployment
```

### 3. Monitor Deployment
```bash
# Check deployment status
release deploys list --app <app-name>

# Get deployment logs if available
release deploys logs <deploy-id>
```

## Prevention Strategies

### 1. Use Release-Specific Names
Consider using release name prefixes in your Helm templates:
```yaml
fullnameOverride: "{{ .Release.Name }}-loki"
nameOverride: "{{ .Release.Name }}-loki"
```

### 2. Disable All Monitoring Components
For ephemeral environments, disable all monitoring that creates ClusterRoles:
```yaml
# In values.yaml or override values
global:
  monitoring:
    enabled: false
```

### 3. Use Namespaced Resources Only
Ensure all resources are namespaced and avoid cluster-scoped resources in ephemeral environments.

## Troubleshooting Commands

```bash
# Check if the issue is resolved
release environments get <environment-id>

# Restart deployment if needed
release deploys create --app <app-name> --environment <environment-id>

# Check application logs
release instances logs <instance-id>
```

## Contact Support
If issues persist after applying these fixes:
1. Provide the exact error message
2. Include your Helm chart configuration
3. Share the Release.com deployment logs
4. Mention this ClusterRole conflict resolution attempt
