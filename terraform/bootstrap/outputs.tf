# IAM Bootstrap Outputs
# Following the "Built for Clarity" design philosophy

output "redstone_dev_deploy_user_arn" {
  description = "ARN of the development deployment user"
  value       = aws_iam_user.redstone_dev_deploy.arn
}

output "redstone_prod_deploy_user_arn" {
  description = "ARN of the production deployment user"
  value       = aws_iam_user.redstone_prod_deploy.arn
}

output "redstone_ci_cd_user_arn" {
  description = "ARN of the CI/CD user"
  value       = aws_iam_user.redstone_ci_cd.arn
}

# Access Keys (sensitive)
output "redstone_dev_deploy_access_key_id" {
  description = "Access key ID for development deployment user"
  value       = aws_iam_access_key.redstone_dev_deploy.id
  sensitive   = true
}

output "redstone_dev_deploy_secret_access_key" {
  description = "Secret access key for development deployment user"
  value       = aws_iam_access_key.redstone_dev_deploy.secret
  sensitive   = true
}

output "redstone_prod_deploy_access_key_id" {
  description = "Access key ID for production deployment user"
  value       = aws_iam_access_key.redstone_prod_deploy.id
  sensitive   = true
}

output "redstone_prod_deploy_secret_access_key" {
  description = "Secret access key for production deployment user"
  value       = aws_iam_access_key.redstone_prod_deploy.secret
  sensitive   = true
}

output "redstone_ci_cd_access_key_id" {
  description = "Access key ID for CI/CD user"
  value       = aws_iam_access_key.redstone_ci_cd.id
  sensitive   = true
}

output "redstone_ci_cd_secret_access_key" {
  description = "Secret access key for CI/CD user"
  value       = aws_iam_access_key.redstone_ci_cd.secret
  sensitive   = true
}

# IAM Roles
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node group service role"
  value       = aws_iam_role.eks_node_role.arn
}

# IAM Groups
output "redstone_developers_group_arn" {
  description = "ARN of the developers group"
  value       = aws_iam_group.redstone_developers.arn
}

output "redstone_operators_group_arn" {
  description = "ARN of the operators group"
  value       = aws_iam_group.redstone_operators.arn
}

output "redstone_admins_group_arn" {
  description = "ARN of the admins group"
  value       = aws_iam_group.redstone_admins.arn
}

# Policy ARNs
output "redstone_dev_policy_arn" {
  description = "ARN of the development policy"
  value       = aws_iam_policy.redstone_dev_policy.arn
}

output "redstone_prod_policy_arn" {
  description = "ARN of the production policy"
  value       = aws_iam_policy.redstone_prod_policy.arn
}

output "redstone_ci_cd_policy_arn" {
  description = "ARN of the CI/CD policy"
  value       = aws_iam_policy.redstone_ci_cd_policy.arn
}

# Summary for easy reference
output "deployment_credentials" {
  description = "Summary of deployment credentials"
  value = {
    development = {
      user_arn = aws_iam_user.redstone_dev_deploy.arn
      user_name = aws_iam_user.redstone_dev_deploy.name
    }
    production = {
      user_arn = aws_iam_user.redstone_prod_deploy.arn
      user_name = aws_iam_user.redstone_prod_deploy.name
    }
    ci_cd = {
      user_arn = aws_iam_user.redstone_ci_cd.arn
      user_name = aws_iam_user.redstone_ci_cd.name
    }
  }
  sensitive = false
}
