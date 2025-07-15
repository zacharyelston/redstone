# Release.com Deployment Guide

This guide explains how to deploy the Redstone project to Release.com.

## Prerequisites

- A GitHub account with access to the Redstone repository
- A Release.com account with appropriate permissions
- Git installed on your local machine

## Deployment Workflow

Release.com provides several methods for setting up and deploying your environment:

1. **Release UI**: Quick guided setup through the Release.com web interface
2. **GitHub PR**: Version-controlled deployments through GitHub pull requests
3. **Release CLI**: Programmable deployments through the command-line interface

### Method 1: Deploy via Git Pull Request (Recommended)

As shown in the Release.com UI, follow these steps to deploy via a Git pull request:

#### Via GitHub UI:

1. Create a new branch in your repository
2. Make your changes to add environment configuration
3. Create a pull request for review and deployment

#### Via Terminal:

1. Create and check out a new branch:
   ```bash
   # Create and check out a new branch
   git checkout -b my-environment-branch
   ```

2. Make your changes to the configuration files

3. Stage, commit and push your changes:
   ```bash
   # Stage your changes
   git add .
   
   # Commit your changes
   git commit -m "Add environment changes"
   
   # Push to origin
   git push -u origin my-environment-branch
   ```

4. Create a pull request in GitHub for review and deployment

### Important Reminders:

- You need to create or select a branch first - PRs cannot be created directly to main
- Your changes must be committed to your branch before creating a PR
- Use the configuration files in the `.release` directory as starting points

## Configuration Files

The Redstone project includes the following template files in the `.release` directory:

1. **application_template.yaml**: Defines the application structure, resources, and health checks
2. **environment_template.yaml**: Configures environment-specific settings for services
3. **service_template.yaml**: Provides template for individual microservice configuration
4. **variables.yaml**: Contains all variables with descriptions and default values

When deploying, you should:

1. Create your environment configuration based on the templates
2. Replace variable placeholders with actual values (especially secret values)
3. Never commit secret values to the repository

## Directory Structure

```
.release/
├── application_template.yaml  # Application structure and shared resources
├── environment_template.yaml  # Environment-specific configurations
├── service_template.yaml      # Optional template for microservices
└── variables.yaml            # Variable definitions with defaults
```

## Variable Substitution

Variables in the templates are marked with `${VARIABLE_NAME}` syntax. Secret values should be managed through Release.com secrets or environment variables.

## Troubleshooting

If you encounter issues during deployment:

1. Check the Release.com logs for specific error messages
2. Verify that all required variables are properly set in your environment
3. Ensure that resource allocations match the requirements of your environment
4. Check that health check endpoints are correctly configured and accessible

For additional help, refer to the [Release.com documentation](https://docs.release.com) or contact the Redstone project maintainers.
