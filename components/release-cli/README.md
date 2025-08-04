# Release.com CLI Secrets Management

This directory contains tools for managing Release.com environment variables and secrets for the Redstone deployment.

## Overview

The `create-release-secrets.sh` script automates the creation of all necessary environment variables and secrets in Release.com for deploying the Redstone stack. It uses a JSON configuration file to define all variables, making it easy to maintain and customize.

## Prerequisites

1. **Install Release CLI**:
   ```bash
   npm install -g @release-app/cli
   ```

2. **Authenticate with Release.com**:
   ```bash
   release login
   ```

3. **Optional: Install jq** (for better JSON parsing):
   ```bash
   # macOS
   brew install jq
   
   # Linux
   apt-get install jq
   ```

## Quick Start

1. Make the script executable:
   ```bash
   chmod +x create-release-secrets.sh
   ```

2. Run the script:
   ```bash
   ./create-release-secrets.sh
   ```

3. Follow the interactive prompts to:
   - Select your Release.com application
   - Choose the environment (development/staging/production)
   - Auto-generate or provide custom passwords

## Usage Options

### Basic Usage
```bash
./create-release-secrets.sh
```

### Dry Run Mode
Preview what would be created without making changes:
```bash
./create-release-secrets.sh --dry-run
```

### Auto-Generate All Passwords
Skip password prompts and generate all automatically:
```bash
./create-release-secrets.sh --auto
```

### Specify App and Environment
Bypass interactive selection:
```bash
./create-release-secrets.sh --app myapp --env production
```

### Use Custom Configuration
```bash
./create-release-secrets.sh --config my-custom-config.json
```

### Combined Options
```bash
./create-release-secrets.sh --auto --app redstone --env production --dry-run
```

## Configuration File

The `release-secrets.json` file defines all environment variables and secrets. It's organized into sections:

### Structure

```json
{
  "variables": {
    "configuration": [...],  // General config like LOG_LEVEL
    "services": [...],      // Service versions and ports
    "secrets": [...],       // Sensitive values (passwords, tokens)
    "optional": [...]       // Optional variables
  },
  "profiles": {            // Environment-specific overrides
    "development": {...},
    "production": {...}
  }
}
```

### Variable Types

1. **Configuration Variables**: General settings
   - Support template substitution: `${APP_NAME}`, `${ENV_NAME}`
   - Can include options and descriptions

2. **Service Variables**: Versions and ports
   - Organized by category (database, monitoring, etc.)
   - Non-sensitive values

3. **Secrets**: Sensitive values
   - Auto-generated passwords with specified lengths
   - Marked with `--secret` flag in Release.com
   - Encrypted storage

4. **Optional Variables**: User-prompted values
   - Only created if user provides values
   - Useful for API tokens and external integrations

## Customization

### Adding New Variables

Edit `release-secrets.json`:

```json
{
  "variables": {
    "services": [
      {
        "name": "MY_NEW_SERVICE_VERSION",
        "value": "1.0.0",
        "category": "custom",
        "description": "My custom service version"
      }
    ]
  }
}
```

### Adding New Secrets

```json
{
  "variables": {
    "secrets": [
      {
        "name": "MY_SECRET_KEY",
        "length": 32,
        "description": "My secret key",
        "category": "custom",
        "required": true
      }
    ]
  }
}
```

### Creating Environment Profiles

```json
{
  "profiles": {
    "staging": {
      "overrides": {
        "LOG_LEVEL": "debug",
        "CLUSTER_NAME": "staging-${APP_NAME}"
      }
    }
  }
}
```

## Security

- All passwords are generated using cryptographically secure methods
- Secrets are marked with `--secret` flag for encrypted storage
- Credentials can be saved locally with secure permissions (600)
- Saved credentials are stored in `~/.redstone/credentials/`

## Credential Management

If you choose to save credentials locally:

1. They're saved to: `~/.redstone/credentials/redstone-APP-ENV-timestamp.txt`
2. File permissions are set to 600 (owner read/write only)
3. **Important**: Delete these files after noting the credentials

## Verifying Secrets

After running the script, verify your secrets:

```bash
# List all environment variables
release env list --app="your-app" --env="your-env"

# Check specific variable
release env get POSTGRES_PASSWORD --app="your-app" --env="your-env"
```

## Troubleshooting

### Release CLI Not Found
```bash
npm install -g @release-app/cli
```

### Authentication Failed
```bash
release login
```

### jq Not Installed
The script will work without jq but with limited features. Install jq for full functionality:
```bash
brew install jq  # macOS
apt-get install jq  # Linux
```

### Permission Denied
```bash
chmod +x create-release-secrets.sh
```

## Integration with CI/CD

For automated deployments, use the script in CI/CD:

```bash
# GitHub Actions example
- name: Setup Release.com Secrets
  run: |
    npm install -g @release-app/cli
    release login --token ${{ secrets.RELEASE_TOKEN }}
    ./create-release-secrets.sh --auto --app redstone --env production
```

## Next Steps

After creating secrets:

1. **Deploy your application**:
   ```bash
   release deploy --app="your-app" --env="your-env"
   ```

2. **Monitor deployment**:
   ```bash
   release status --app="your-app"
   ```

3. **View logs**:
   ```bash
   release logs --app="your-app" --env="your-env"
   ```

## Support

For more information:
- [Release.com CLI Documentation](https://docs.release.com/cli/getting-started)
- [Release.com Environment Variables](https://docs.release.com/configuration/environment-variables)
