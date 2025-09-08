# Image Tag Strategy for Multi-Environment Deployments

## Overview
This document outlines the image tag strategy for maintaining stability in production while allowing flexibility in development environments.

## Strategy

### Development Environments
- **Branches**: `dev`, `feature/*`, `hotfix/*`, `bugfix/*`
- **Image Tags**: `latest`
- **Purpose**: Allow testing of newest features and fixes
- **Values File**: `values-development.yaml`

### Production Environments  
- **Branches**: `main`, `master`, `prod`, `staging`, `release/*`
- **Image Tags**: Pinned versions
- **Purpose**: Ensure stability and predictable deployments
- **Values File**: `values-production.yaml`

## Current Pinned Versions (Production)

| Component | Production Tag | Latest Tag |
|-----------|---------------|------------|
| Redmica | `5.1.0` | `latest` |
| Redis | `7.0.15-debian-11-r7` | `latest` |
| LDAP | `v0.5.0` | `latest` |
| Loki | `3.0.0` | `latest` |
| Grafana | `10.4.0` | `latest` |
| Prometheus | `v2.51.2` | `latest` |
| Pushgateway | `v1.8.0` | `latest` |
| Node Exporter | `v1.7.0` | `latest` |
| Fluent Bit | `3.0.7` | `latest` |

## Deployment Commands

### Development
```bash
helm upgrade --install redstone ./helm/redstone \
  -f values.yaml \
  -f values-development.yaml \
  --namespace dev
```

### Production
```bash
helm upgrade --install redstone ./helm/redstone \
  -f values.yaml \
  -f values-production.yaml \
  --namespace production
```

### Ephemeral Environments
Currently using development configuration (latest tags) for all ephemeral environments to resolve image pull issues.

## Version Update Process

### For Development
No action needed - `latest` tags automatically pull newest versions.

### For Production
1. Test new versions in development first
2. Update pinned versions in `values-production.yaml`
3. Test in staging environment
4. Deploy to production with new pinned versions

## Benefits

- **Development**: Fast iteration with latest features
- **Production**: Predictable, stable deployments
- **Security**: Known versions for vulnerability tracking
- **Rollback**: Easy to revert to previous known-good versions
