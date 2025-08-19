#!/bin/bash
# Terraform Bootstrap Script
# Following the "Built for Clarity" design philosophy
# Creates S3 bucket and DynamoDB table for Terraform state management

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
Usage: $0 [OPTIONS] ENVIRONMENT

Bootstrap Terraform backend infrastructure for Redstone deployment.

ARGUMENTS:
    ENVIRONMENT     Environment name (dev, prod, staging)

OPTIONS:
    -h, --help      Show this help message
    -r, --region    AWS region (default: us-west-2)
    -f, --force     Force creation even if resources exist

EXAMPLES:
    # Bootstrap development environment
    $0 dev

    # Bootstrap production with specific region
    $0 prod --region us-east-1

    # Force recreation of existing resources
    $0 dev --force

EOF
}

# Default values
AWS_REGION="us-west-2"
FORCE=false
ENVIRONMENT=""

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
        -f|--force)
            FORCE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$ENVIRONMENT" ]]; then
                ENVIRONMENT="$1"
            else
                print_error "Too many arguments"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment is required"
    usage
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|prod|staging)$ ]]; then
    print_error "Environment must be one of: dev, prod, staging"
    exit 1
fi

# Set resource names
DEPLOY_NAME="redstone-${ENVIRONMENT}"
S3_BUCKET="${DEPLOY_NAME}-terraform-state"
DYNAMODB_TABLE="${DEPLOY_NAME}-terraform-locks"

print_status "Bootstrapping Terraform backend for ${DEPLOY_NAME}"
print_status "Region: ${AWS_REGION}"
print_status "S3 Bucket: ${S3_BUCKET}"
print_status "DynamoDB Table: ${DYNAMODB_TABLE}"
echo

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured"
    print_warning "Run: aws configure"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: ${AWS_ACCOUNT_ID}"

# Function to create S3 bucket
create_s3_bucket() {
    print_status "Creating S3 bucket: ${S3_BUCKET}"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            print_warning "Bucket exists, but --force specified"
        else
            print_success "S3 bucket already exists: ${S3_BUCKET}"
            return 0
        fi
    fi
    
    # Create bucket
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
        aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$S3_BUCKET" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$S3_BUCKET" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$S3_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$S3_BUCKET" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    # Add tags
    aws s3api put-bucket-tagging \
        --bucket "$S3_BUCKET" \
        --tagging 'TagSet=[
            {Key=Project,Value=redstone},
            {Key=Environment,Value='$ENVIRONMENT'},
            {Key=ManagedBy,Value=terraform},
            {Key=Purpose,Value=terraform-state}
        ]'
    
    print_success "S3 bucket created: ${S3_BUCKET}"
}

# Function to create DynamoDB table
create_dynamodb_table() {
    print_status "Creating DynamoDB table: ${DYNAMODB_TABLE}"
    
    # Check if table exists
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            print_warning "Table exists, but --force specified"
            print_status "Deleting existing table..."
            aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
            
            # Wait for deletion
            print_status "Waiting for table deletion..."
            aws dynamodb wait table-not-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
        else
            print_success "DynamoDB table already exists: ${DYNAMODB_TABLE}"
            return 0
        fi
    fi
    
    # Create table
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=redstone Key=Environment,Value="$ENVIRONMENT" Key=ManagedBy,Value=terraform Key=Purpose,Value=terraform-locks
    
    # Wait for table to be active
    print_status "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    
    print_success "DynamoDB table created: ${DYNAMODB_TABLE}"
}

# Function to generate backend configuration
generate_backend_config() {
    local backend_file="backend-${ENVIRONMENT}.hcl"
    
    print_status "Generating backend configuration: ${backend_file}"
    
    cat > "$backend_file" << EOF
# Terraform Backend Configuration for ${ENVIRONMENT}
# Generated by bootstrap.sh

bucket         = "${S3_BUCKET}"
key            = "terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true

# Additional backend configuration
workspace_key_prefix = "workspaces"
EOF
    
    print_success "Backend configuration saved: ${backend_file}"
    print_status "Initialize Terraform with: terraform init -backend-config=${backend_file}"
}

# Main execution
main() {
    print_status "Starting Terraform backend bootstrap"
    echo
    
    create_s3_bucket
    echo
    
    create_dynamodb_table
    echo
    
    generate_backend_config
    echo
    
    print_success "Terraform backend bootstrap completed!"
    print_status "Next steps:"
    echo "  1. cd terraform/"
    echo "  2. terraform init -backend-config=backend-${ENVIRONMENT}.hcl"
    echo "  3. terraform plan -var-file=environments/${ENVIRONMENT}.tfvars"
    echo "  4. terraform apply -var-file=environments/${ENVIRONMENT}.tfvars"
}

# Run main function
main "$@"
