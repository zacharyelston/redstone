# Redstone

A modular, Docker-based application designed for deployment on Release.com.

## Overview

Redstone is built according to the "Built for Clarity" design philosophy, emphasizing simplicity, modularity, and maintainability. The project is structured to make deployment on Release.com straightforward while maintaining flexibility for local development.

## Project Structure

```
├── docker-compose.yml       # Main deployment configuration
├── .release.yaml            # Release.com specific configuration
├── .env.example             # Example environment variables
├── components/              # Application components/services
│   ├── api/                 # API service
│   ├── frontend/            # Frontend application
│   └── worker/              # Background worker service
└── scripts/                 # Utility scripts
```

## Requirements

- Docker and Docker Compose for local development
- Git for version control
- Release.com account for deployment

## Local Development

1. Clone this repository
2. Copy `.env.example` to `.env` and adjust variables as needed
3. Run `docker-compose up` to start all services locally
4. Access the application at http://localhost:8080

## Deployment on Release.com

This repository is configured for easy deployment to Release.com:

1. Connect your Release.com account to this repository
2. Create a new application in Release.com using this repository
3. Configure environment-specific variables in the Release.com dashboard
4. Deploy to your desired environment

## Design Philosophy

Redstone follows the "Built for Clarity" design philosophy:

- **Simplicity Over Complexity**: Favoring clear, straightforward solutions over clever but complex ones
- **Modular Design**: Breaking the system into independent, focused components
- **Encapsulation**: Hiding internal details through well-defined interfaces
- **SOLID Principles**: Following proven design patterns for maintainability
- **Practical Heuristics**: Using KISS, DRY, and YAGNI as guiding principles
- **Continuous Refinement**: Treating design as an ongoing process

## License

MIT