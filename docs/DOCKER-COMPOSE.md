# Redstone Docker Compose Deployment Guide

This document provides comprehensive guidance for deploying Redstone using Docker Compose, which is ideal for development environments and small-scale deployments.

## Overview

Docker Compose provides a simple way to define and run multi-container Docker applications. For Redstone, this means you can quickly spin up all the necessary services on a single machine without the complexity of Kubernetes.

## Architecture

The Docker Compose deployment of Redstone consists of the following components:

1. **PostgreSQL** - Database for Redmica
2. **OpenLDAP** - User authentication and management
3. **Redmica** - Project management application (Redmine fork)
4. **Monitoring Stack** - Prometheus and Grafana for monitoring

Each component runs in its own container with appropriate configuration and networking.

## Prerequisites

Before deploying Redstone with Docker Compose, ensure you have:

- Docker Engine (version 20.10.0 or later)
- Docker Compose (version 2.0.0 or later)
- At least 4GB of RAM available for Docker
- At least 10GB of free disk space

## Quick Start

For a simple deployment with default settings:

```bash
# Start the deployment
./deploy.sh

# Stop the deployment
./stop.sh
```

## Manual Deployment

If you prefer to run commands manually or need more control:

```bash
# Start all services
docker-compose up -d

# Start only specific components
docker-compose up -d redmica postgres

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes (caution: this deletes all data)
docker-compose down -v
```

## Configuration

### Environment Variables

The deployment can be customized using environment variables:

- `REDMICA_VERSION`: Redmica version to deploy (default: 3.1.7)
- `POSTGRES_VERSION`: PostgreSQL version (default: 15)
- `REDMICA_PORT`: Port to expose Redmica on (default: 3000)
- `POSTGRES_PASSWORD`: PostgreSQL password (default: postgres)
- `REDMICA_SECRET_KEY_BASE`: Secret key for Redmica sessions

Set these variables in a `.env` file or export them before running docker-compose.

### Volume Persistence

Data is persisted in Docker volumes:

- `redmica_files`: Redmica file attachments
- `redmica_plugins`: Redmica plugins
- `postgres_data`: PostgreSQL database files
- `ldap_data`: OpenLDAP data

These volumes ensure your data survives container restarts.

## Component Configuration

### Redmica

Redmica is configured through environment variables in the docker-compose.yaml file:

```yaml
redmica:
  image: redmica/redmica:3.1.7
  environment:
    REDMINE_DB_POSTGRES: postgres
    REDMINE_DB_USERNAME: postgres
    REDMINE_DB_PASSWORD: ${POSTGRES_PASSWORD}
    REDMINE_SECRET_KEY_BASE: ${REDMICA_SECRET_KEY_BASE}
    REDMINE_PLUGINS_MIGRATE: 'true'
  volumes:
    - redmica_files:/usr/src/redmine/files
    - redmica_plugins:/usr/src/redmine/plugins
  ports:
    - "${REDMICA_PORT:-3000}:3000"
  depends_on:
    - postgres
  restart: unless-stopped
```

### PostgreSQL

PostgreSQL is configured with:

```yaml
postgres:
  image: postgres:${POSTGRES_VERSION:-15}
  environment:
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    POSTGRES_USER: postgres
    POSTGRES_DB: redmica_production
  volumes:
    - postgres_data:/var/lib/postgresql/data
  restart: unless-stopped
```

### OpenLDAP

OpenLDAP is used for user authentication:

```yaml
openldap:
  image: osixia/openldap:latest
  environment:
    LDAP_DOMAIN: ${LDAP_DOMAIN:-redstone.local}
    LDAP_ADMIN_PASSWORD: ${LDAP_ADMIN_PASSWORD:-admin}
  volumes:
    - ldap_data:/var/lib/ldap
    - ldap_config:/etc/ldap/slapd.d
  ports:
    - "389:389"
  restart: unless-stopped
```

### Monitoring Stack

The monitoring stack includes Prometheus and Grafana:

```yaml
grafana:
  image: grafana/grafana:latest
  ports:
    - "3001:3000"
  volumes:
    - grafana_data:/var/lib/grafana
  environment:
    GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
  restart: unless-stopped

prometheus:
  image: prom/prometheus:latest
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  restart: unless-stopped
```

## Complete docker-compose.yml Example

Here's a complete example of the docker-compose.yml file:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:${POSTGRES_VERSION:-15}
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_USER: postgres
      POSTGRES_DB: redmica_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redmica:
    image: redmica/redmica:${REDMICA_VERSION:-3.1.7}
    environment:
      REDMINE_DB_POSTGRES: postgres
      REDMINE_DB_USERNAME: postgres
      REDMINE_DB_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      REDMINE_SECRET_KEY_BASE: ${REDMICA_SECRET_KEY_BASE:-changemeinproduction}
      REDMINE_PLUGINS_MIGRATE: 'true'
    volumes:
      - redmica_files:/usr/src/redmine/files
      - redmica_plugins:/usr/src/redmine/plugins
    ports:
      - "${REDMICA_PORT:-3000}:3000"
    depends_on:
      - postgres
    restart: unless-stopped

  openldap:
    image: osixia/openldap:latest
    environment:
      LDAP_DOMAIN: ${LDAP_DOMAIN:-redstone.local}
      LDAP_ADMIN_PASSWORD: ${LDAP_ADMIN_PASSWORD:-admin}
    volumes:
      - ldap_data:/var/lib/ldap
      - ldap_config:/etc/ldap/slapd.d
    ports:
      - "389:389"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    restart: unless-stopped

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - loki_data:/loki
    restart: unless-stopped

volumes:
  postgres_data:
  redmica_files:
  redmica_plugins:
  ldap_data:
  ldap_config:
  grafana_data:
  prometheus_data:
  loki_data:
```

## Backup and Restore

### Backup

To backup your Redstone deployment:

```bash
# Create a backup directory
mkdir -p ./backup/$(date +%Y%m%d)
cd ./backup/$(date +%Y%m%d)

# Backup PostgreSQL database
docker-compose exec -T postgres pg_dump -U postgres redmica_production > redmica_db.sql

# Backup Redmica files
docker cp $(docker-compose ps -q redmica):/usr/src/redmine/files ./redmica_files
```

### Restore

To restore from a backup:

```bash
# Restore PostgreSQL database
cat backup/YYYYMMDD/redmica_db.sql | docker-compose exec -T postgres psql -U postgres redmica_production

# Restore Redmica files
docker cp ./backup/YYYYMMDD/redmica_files/. $(docker-compose ps -q redmica):/usr/src/redmine/files/
```

## Troubleshooting

### Common Issues

1. **Database connection issues:**
   - Ensure PostgreSQL is running: `docker-compose ps postgres`
   - Check PostgreSQL logs: `docker-compose logs postgres`
   - Verify environment variables are set correctly

2. **Redmica not starting:**
   - Check Redmica logs: `docker-compose logs redmica`
   - Verify database migration succeeded
   - Ensure volumes are properly mounted

3. **LDAP authentication problems:**
   - Verify OpenLDAP is running: `docker-compose ps openldap`
   - Check LDAP configuration in Redmica settings
   - Test LDAP connectivity: `docker-compose exec redmica ldapsearch`

## Release.com Deployment

For deploying to Release.com, refer to the main README.md and the `.release.yaml` configuration.
