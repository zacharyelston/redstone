# Release.com Static Environment Deployment Guide

This guide explains how to deploy Redstone to Release.com using our static dev/test/prod environment strategy with git tag-based deployments.

## Overview

Redstone uses a **static environment strategy** with Release.com, providing:

- ✅ **Static environments** that persist between deployments
- ✅ **Git tag-based releases** for controlled deployments  
- ✅ **Proper environment promotion** (dev → staging → prod)
- ✅ **Manual approval gates** for staging and production
- ✅ **Continuous deployment** to development from main branch
- ✅ **Automated testing** after each deployment

## Environment Strategy

### **Development Environment**
- **Trigger**: Push to `main` branch
- **Deployment**: Automatic (continuous deployment)
- **URL**: `https://dev.redstone.example.com`
- **Purpose**: Latest development code, immediate feedback

### **Staging Environment**  
- **Trigger**: Release candidate tags (`v*-rc.*`)
- **Deployment**: Manual approval required
- **URL**: `https://staging.redstone.example.com`
- **Purpose**: Pre-production testing, QA validation

### **Production Environment**
- **Trigger**: Stable release tags (`v*` excluding `-rc`)
- **Deployment**: Manual approval required  
- **URL**: `https://redstone.example.com`
- **Purpose**: Live production system

## Git Tag-Based Release Workflow

### **Development Workflow**
```bash
# Continuous deployment to development
git push origin main  # → Auto-deploys to dev environment
```

### **Release Candidate Workflow**
```bash
# Create and deploy release candidate
git tag v1.2.0-rc.1
git push origin v1.2.0-rc.1  # → Triggers staging deployment (manual approval)

# Additional release candidates if needed
git tag v1.2.0-rc.2
git push origin v1.2.0-rc.2
```

### **Production Release Workflow**
```bash
# Deploy to production
git tag v1.2.0
git push origin v1.2.0  # → Triggers production deployment (manual approval)
```

### **Hotfix Workflow**
```bash
# Emergency production fix
git tag v1.2.1
git push origin v1.2.1  # → Triggers production deployment (manual approval)
```

## Manual Deployment

You can also trigger deployments manually via GitHub Actions:

1. Go to **Actions** → **Release.com Static Environment Deployment**
2. Click **Run workflow**
3. Select target environment (development/staging/production)
4. Optionally enable **force_deploy** to skip some checks

## Environment Configuration

### **Required GitHub Secrets**

Set these secrets in your GitHub repository settings:

```bash
# Release.com API access
RELEASE_API_TOKEN=your_release_api_token

# Development environment
RELEASE_DEV_APP_ID=your_dev_app_id
RELEASE_DEV_ENV_ID=your_dev_env_id

# Staging environment  
RELEASE_STAGING_APP_ID=your_staging_app_id
RELEASE_STAGING_ENV_ID=your_staging_env_id

# Production environment
RELEASE_PROD_APP_ID=your_prod_app_id
RELEASE_PROD_ENV_ID=your_prod_env_id
```

### **Environment-Specific Resources**

Each environment has different resource allocations:

| Environment | CPU | Memory | Replicas | Persistence |
|-------------|-----|--------|----------|-------------|
| Development | 1 core | 2Gi | 1 | Yes (static) |
| Staging | 1.5 cores | 3Gi | 1 | Yes (static) |
| Production | 2 cores | 4Gi | 2 | Yes (static) |

## Automated Testing

### **Pre-Deployment Testing**
- Docker Compose build and health checks
- Redstone deployment validation tests
- Service connectivity verification

### **Post-Deployment Testing**
- Application health endpoint checks
- Environment-specific URL validation
- Service availability verification

## Release.com CLI Management

### **Setup Release.com CLI**
```bash
# Install Release.com CLI dependencies
pip install requests

# Use the automated secrets setup
cd components/release-cli
./create-release-secrets.sh
```

### **Manual Deployment via CLI**
```bash
# Deploy to specific environment
python deploy/release/api/client.py deploy \
  --app-id YOUR_APP_ID \
  --env-id YOUR_ENV_ID \
  --environment development
```

## Monitoring and Troubleshooting

### **Deployment Status**
- Monitor deployments in GitHub Actions
- Check Release.com dashboard for environment status
- Review deployment logs for issues

### **Health Checks**
Each service has configured health checks:
- **Redmica**: `GET /` on port 3000
- **PostgreSQL**: TCP check on port 5432  
- **LDAP**: TCP check on port 389
- **Grafana**: `GET /api/health` on port 3001
- **Prometheus**: `GET /-/healthy` on port 9090

### **Common Issues**

**Deployment Fails**
- Check GitHub Secrets are correctly configured
- Verify Release.com API token has proper permissions
- Review environment-specific configuration files

**Health Checks Fail**
- Allow more time for services to start (60+ seconds)
- Check resource allocations are sufficient
- Verify service dependencies are healthy

**Environment Not Updating**
- Ensure git tags follow proper format (`v1.2.3` or `v1.2.3-rc.1`)
- Check GitHub Actions workflow triggers
- Verify manual approval for staging/production

## Best Practices

### **Release Management**
1. **Always test in staging** before production deployment
2. **Use semantic versioning** for git tags (v1.2.3)
3. **Create release candidates** for major changes (v1.2.3-rc.1)
4. **Document changes** in git commit messages and PR descriptions

### **Environment Hygiene**
1. **Static environments persist** - they don't get destroyed between deployments
2. **Resource limits** prevent environment resource conflicts
3. **Health checks** ensure service availability before marking deployment successful
4. **Automated testing** validates deployment integrity

### **Security**
1. **Never commit secrets** to the repository
2. **Use GitHub Secrets** for sensitive configuration
3. **Environment isolation** prevents cross-environment access
4. **Manual approvals** for production deployments

## Support

For additional help:
- Review [Release.com documentation](https://docs.release.com)
- Check GitHub Actions logs for deployment details
- Contact the Redstone project maintainers
- Review the Release.com CLI tools in `components/release-cli/`
