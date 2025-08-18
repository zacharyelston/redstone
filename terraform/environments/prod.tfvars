# Production Environment Configuration
# Following the "Built for Clarity" design philosophy

deploy_name    = "redstone-prod"
environment    = "production"
aws_region     = "us-west-2"
aws_account_id = "238397745651"

# VPC Configuration
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# EKS Configuration
eks_cluster_version      = "1.28"
eks_node_instance_types  = ["t3.large", "t3.xlarge"]
eks_node_desired_capacity = 3
eks_node_max_capacity     = 10
eks_node_min_capacity     = 2

# Database Configuration
rds_instance_class        = "db.t3.small"
rds_allocated_storage     = 100
rds_max_allocated_storage = 500

# Production-specific settings
enable_deletion_protection = true
log_retention_days        = 90

# Additional tags
additional_tags = {
  Owner       = "platform-team"
  CostCenter  = "operations"
  Backup      = "continuous"
  Compliance  = "required"
}
