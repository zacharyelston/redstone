# Terraform Outputs
# Following the "Built for Clarity" design philosophy
# Essential information for Helm chart deployment and operations

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = false
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS node group"
  value       = module.eks.node_security_group_id
}

output "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = false
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "database_username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "database_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "s3_assets_bucket" {
  description = "S3 bucket for application assets"
  value       = aws_s3_bucket.assets.bucket
}

output "s3_assets_bucket_arn" {
  description = "S3 bucket ARN for application assets"
  value       = aws_s3_bucket.assets.arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Helm values for Redstone chart
output "helm_values" {
  description = "Helm values for Redstone deployment"
  value = {
    global = {
      aws = {
        region     = data.aws_region.current.name
        account_id = data.aws_caller_identity.current.account_id
      }
      database = {
        host     = aws_db_instance.postgres.endpoint
        port     = aws_db_instance.postgres.port
        name     = aws_db_instance.postgres.db_name
        username = aws_db_instance.postgres.username
      }
      storage = {
        s3_bucket = aws_s3_bucket.assets.bucket
      }
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
      }
    }
  }
  sensitive = false
}
