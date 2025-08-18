# Terraform Backend Configuration
# Following the "Built for Clarity" design philosophy
# S3 backend with DynamoDB state locking for safe concurrent operations

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # These values will be set during terraform init
    # bucket         = "redstone-{env}-terraform-state"
    # key            = "terraform.tfstate"
    # region         = "us-west-2"
    # dynamodb_table = "redstone-{env}-terraform-locks"
    # encrypt        = true
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "redstone"
      Environment = var.environment
      ManagedBy   = "terraform"
      DeployName  = var.deploy_name
    }
  }
}
