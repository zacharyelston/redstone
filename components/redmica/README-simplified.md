# Redmica Configuration Automation - Simplified Approach

## Overview

This approach uses proven, industry-standard tools instead of custom solutions:

- **envsubst** for configuration templating (built into most containers)
- **Rails db:seed** for data initialization (Rails standard)
- **external-secrets-operator** for Kubernetes secret management
- **dockerize** for service dependency waiting

## Quick Setup

### 1. Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
# Edit .env with your specific values
```

### 2. Docker Usage

```bash
docker run -d \
  --env-file .env \
  -p 3000:3000 \
  redmica:automated
```

### 3. Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redmica
spec:
  template:
    spec:
      containers:
      - name: redmica
        image: redmica:automated
        envFrom:
        - configMapRef:
            name: redmica-config
        - secretRef:
            name: redmica-secrets
```

## How It Works

### Configuration Processing
- Uses `envsubst` (standard Unix tool) to substitute environment variables
- No custom Ruby scripts to maintain
- Works with any container runtime

### Data Seeding
- Uses Rails' built-in `db:seed` functionality
- Standard Rails patterns with `find_or_create_by` for idempotency
- No custom database logic

### Secret Management
- Kubernetes: external-secrets-operator with your existing secret backend
- Docker: environment variables or mounted secret files
- No custom secret management code

### Service Dependencies
- Uses `dockerize` for waiting on database availability
- Standard tool used by many Docker images
- Reliable and well-tested

## Benefits of This Approach

1. **Less Code to Maintain**: Uses existing, proven tools
2. **Industry Standards**: Follows established patterns
3. **Better Support**: Community-maintained tools with documentation
4. **Easier Debugging**: Standard tools with known behavior
5. **Reduced Complexity**: Simpler architecture

## Migration from Custom Scripts

Replace the custom startup script with this simple entrypoint:

```bash
#!/bin/bash
set -e

# Standard configuration processing
envsubst < /app/config/configuration.yml.envsubst > /app/config/configuration.yml

# Standard dependency waiting
dockerize -wait tcp://${DATABASE_HOST}:5432 -timeout 60s

# Standard Rails database setup
bundle exec rake db:create db:migrate db:seed

# Start application
exec "$@"
```

This achieves the same automation goals with significantly less custom code.
