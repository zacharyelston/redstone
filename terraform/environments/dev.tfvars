# Development Environment Configuration
# Following the "Built for Clarity" design philosophy

deploy_name    = "redstone-dev"
environment    = "development"
aws_region     = "us-west-2"
aws_account_id = "238397745651"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

# EKS Configuration
eks_cluster_version      = "1.28"
eks_node_instance_types  = ["t3.medium"]
eks_node_desired_capacity = 2
eks_node_max_capacity     = 5
eks_node_min_capacity     = 1

# Database Configuration
rds_instance_class        = "db.t3.micro"
rds_allocated_storage     = 20
rds_max_allocated_storage = 50

# Development-specific settings
enable_deletion_protection = false
log_retention_days        = 7

# Additional tags
additional_tags = {
  Owner       = "development-team"
  CostCenter  = "engineering"
  Backup      = "daily"
}
