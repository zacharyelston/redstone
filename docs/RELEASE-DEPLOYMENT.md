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
- Use the `application-template.yaml` and `env-template` files as starting points for your configuration

## Configuration Files

The Redstone project includes two key template files for Release.com deployment:

1. **application-template.yaml**: Defines the application structure, resources, and health checks
2. **env-template**: Contains environment variables with placeholders for secret values

When deploying, you should:

1. Make a copy of the `application-template.yaml` file as needed
2. Create an environment-specific version of `env-template` and replace placeholders with actual values
3. Never commit secret values to the repository

## Environment Variables

Secret values in the `env-template` file are marked with double underscores (e.g., `__POSTGRES_PASSWORD__`). Replace these with actual values when deploying, or configure them in the Release.com environment settings.

## Troubleshooting

If you encounter issues during deployment:

1. Check the Release.com logs for specific error messages
2. Verify that all required environment variables are properly set
3. Ensure that resource allocations match the requirements of your environment
4. Check that health check endpoints are correctly configured and accessible

For additional help, refer to the [Release.com documentation](https://docs.release.com) or contact the Redstone project maintainers.
