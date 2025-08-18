#!/bin/bash
# IAM Bootstrap Script
# Following the "Built for Clarity" design philosophy
# Sets up IAM users, groups, and roles for secure Redstone deployments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap IAM infrastructure for Redstone deployments.
This script creates IAM users, groups, and roles needed for secure deployments.

OPTIONS:
    -h, --help      Show this help message
    -r, --region    AWS region (default: us-west-2)
    -a, --apply     Apply changes automatically (default: plan only)
    -d, --destroy   Destroy IAM infrastructure
    -o, --output    Show sensitive outputs after apply

EXAMPLES:
    # Plan IAM changes
    $0

    # Apply IAM changes
    $0 --apply

    # Show outputs after deployment
    $0 --output

    # Destroy IAM infrastructure
    $0 --destroy

PREREQUISITES:
    - AWS CLI configured with root account credentials
    - Terraform installed
    - This should be run ONCE per AWS account

EOF
}

# Default values
AWS_REGION="us-west-2"
APPLY=false
DESTROY=false
SHOW_OUTPUT=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -a|--apply)
            APPLY=true
            shift
            ;;
        -d|--destroy)
            DESTROY=true
            shift
            ;;
        -o|--output)
            SHOW_OUTPUT=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        print_warning "Run: aws configure"
        exit 1
    fi
    
    # Get AWS account info
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
    
    print_status "AWS Account ID: ${AWS_ACCOUNT_ID}"
    print_status "Current User: ${CURRENT_USER}"
    
    # Warn if using root account
    if [[ "$CURRENT_USER" == *":root" ]]; then
        print_warning "You are using the root account"
        print_warning "This is expected for initial IAM bootstrap"
        print_warning "After this setup, use the created service accounts"
    fi
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    if [[ ! -f "terraform.tfvars" ]]; then
        print_error "terraform.tfvars not found"
        print_warning "Copy and customize terraform.tfvars.example"
        exit 1
    fi
    
    terraform init
    terraform validate
    
    print_success "Terraform initialized and validated"
}

# Plan Terraform changes
plan_terraform() {
    print_status "Planning Terraform changes..."
    
    if [[ "$DESTROY" == true ]]; then
        terraform plan -destroy -var="aws_region=${AWS_REGION}"
    else
        terraform plan -var="aws_region=${AWS_REGION}"
    fi
}

# Apply Terraform changes
apply_terraform() {
    print_status "Applying Terraform changes..."
    
    if [[ "$DESTROY" == true ]]; then
        print_warning "This will DESTROY all IAM infrastructure"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            print_status "Aborted"
            exit 0
        fi
        terraform destroy -auto-approve -var="aws_region=${AWS_REGION}"
        print_success "IAM infrastructure destroyed"
    else
        terraform apply -auto-approve -var="aws_region=${AWS_REGION}"
        print_success "IAM infrastructure created"
    fi
}

# Show sensitive outputs
show_outputs() {
    print_status "Retrieving deployment credentials..."
    
    echo
    print_status "=== DEVELOPMENT DEPLOYMENT CREDENTIALS ==="
    echo "Access Key ID: $(terraform output -raw redstone_dev_deploy_access_key_id)"
    echo "Secret Access Key: $(terraform output -raw redstone_dev_deploy_secret_access_key)"
    
    echo
    print_status "=== PRODUCTION DEPLOYMENT CREDENTIALS ==="
    echo "Access Key ID: $(terraform output -raw redstone_prod_deploy_access_key_id)"
    echo "Secret Access Key: $(terraform output -raw redstone_prod_deploy_secret_access_key)"
    
    echo
    print_status "=== CI/CD CREDENTIALS ==="
    echo "Access Key ID: $(terraform output -raw redstone_ci_cd_access_key_id)"
    echo "Secret Access Key: $(terraform output -raw redstone_ci_cd_secret_access_key)"
    
    echo
    print_warning "IMPORTANT: Store these credentials securely!"
    print_warning "Consider using AWS Secrets Manager or similar"
    print_warning "Update your .env files with the appropriate credentials"
}

# Update environment files
update_env_files() {
    print_status "Updating environment configuration..."
    
    local dev_access_key=$(terraform output -raw redstone_dev_deploy_access_key_id)
    local dev_secret_key=$(terraform output -raw redstone_dev_deploy_secret_access_key)
    local prod_access_key=$(terraform output -raw redstone_prod_deploy_access_key_id)
    local prod_secret_key=$(terraform output -raw redstone_prod_deploy_secret_access_key)
    
    # Create environment-specific credential files
    cat > "../environments/dev-credentials.env" << EOF
# Development Deployment Credentials
# Generated by IAM bootstrap - DO NOT COMMIT TO VERSION CONTROL
AWS_ACCESS_KEY_ID=${dev_access_key}
AWS_SECRET_ACCESS_KEY=${dev_secret_key}
AWS_DEFAULT_REGION=${AWS_REGION}
EOF
    
    cat > "../environments/prod-credentials.env" << EOF
# Production Deployment Credentials  
# Generated by IAM bootstrap - DO NOT COMMIT TO VERSION CONTROL
AWS_ACCESS_KEY_ID=${prod_access_key}
AWS_SECRET_ACCESS_KEY=${prod_secret_key}
AWS_DEFAULT_REGION=${AWS_REGION}
EOF
    
    print_success "Credential files created in terraform/environments/"
    print_warning "Add *-credentials.env to .gitignore"
}

# Main execution
main() {
    print_status "Redstone IAM Bootstrap"
    print_status "Region: ${AWS_REGION}"
    echo
    
    check_prerequisites
    echo
    
    init_terraform
    echo
    
    if [[ "$APPLY" == true ]]; then
        apply_terraform
        echo
        
        if [[ "$DESTROY" == false ]]; then
            if [[ "$SHOW_OUTPUT" == true ]]; then
                show_outputs
                echo
            fi
            
            update_env_files
            echo
            
            print_success "IAM bootstrap completed!"
            print_status "Next steps:"
            echo "  1. Store the generated credentials securely"
            echo "  2. Update your deployment scripts to use service accounts"
            echo "  3. Test deployments with the new credentials"
            echo "  4. Disable root account access keys"
        fi
    else
        plan_terraform
        echo
        
        print_status "This was a plan-only run"
        print_status "To apply changes, run: $0 --apply"
    fi
}

# Run main function
main "$@"
