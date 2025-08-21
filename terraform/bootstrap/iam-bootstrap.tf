# IAM Bootstrap Configuration
# Following the "Built for Clarity" design philosophy
# Creates IAM users, groups, and roles for secure Redstone deployments

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = "redstone"
      Component = "iam-bootstrap"
      ManagedBy = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Groups
resource "aws_iam_group" "redstone_developers" {
  name = "redstone-developers"
  path = "/redstone/"
}

resource "aws_iam_group" "redstone_operators" {
  name = "redstone-operators"
  path = "/redstone/"
}

resource "aws_iam_group" "redstone_admins" {
  name = "redstone-admins"
  path = "/redstone/"
}

# IAM Users for Development
resource "aws_iam_user" "redstone_dev_deploy" {
  name = "redstone-dev-deploy"
  path = "/redstone/"
  
  tags = {
    Environment = "development"
    Purpose     = "automated-deployment"
  }
}

resource "aws_iam_user" "redstone_prod_deploy" {
  name = "redstone-prod-deploy"
  path = "/redstone/"
  
  tags = {
    Environment = "production"
    Purpose     = "automated-deployment"
  }
}

resource "aws_iam_user" "redstone_ci_cd" {
  name = "redstone-ci-cd"
  path = "/redstone/"
  
  tags = {
    Environment = "all"
    Purpose     = "ci-cd-pipeline"
  }
}

# Access Keys for Service Users
resource "aws_iam_access_key" "redstone_dev_deploy" {
  user = aws_iam_user.redstone_dev_deploy.name
}

resource "aws_iam_access_key" "redstone_prod_deploy" {
  user = aws_iam_user.redstone_prod_deploy.name
}

resource "aws_iam_access_key" "redstone_ci_cd" {
  user = aws_iam_user.redstone_ci_cd.name
}

# Group Memberships
resource "aws_iam_group_membership" "developers" {
  name = "redstone-developers-membership"
  
  users = [
    aws_iam_user.redstone_dev_deploy.name,
    aws_iam_user.redstone_ci_cd.name,
  ]
  
  group = aws_iam_group.redstone_developers.name
}

resource "aws_iam_group_membership" "operators" {
  name = "redstone-operators-membership"
  
  users = [
    aws_iam_user.redstone_prod_deploy.name,
  ]
  
  group = aws_iam_group.redstone_operators.name
}

# Custom IAM Policies
resource "aws_iam_policy" "redstone_dev_policy" {
  name        = "redstone-dev-policy"
  path        = "/redstone/"
  description = "Policy for Redstone development environment deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EKS permissions
          "eks:*",
          
          # EC2 permissions for EKS nodes
          "ec2:*",
          
          # IAM permissions for service roles
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagRole",
          "iam:UntagRole",
          
          # RDS permissions
          "rds:*",
          
          # S3 permissions
          "s3:*",
          
          # CloudWatch permissions
          "logs:*",
          "cloudwatch:*",
          
          # Application Load Balancer
          "elasticloadbalancing:*",
          
          # Route53 for DNS
          "route53:*",
          
          # Secrets Manager
          "secretsmanager:*",
          
          # Systems Manager Parameter Store
          "ssm:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          # Global services
          "iam:ListAccountAliases",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "redstone_prod_policy" {
  name        = "redstone-prod-policy"
  path        = "/redstone/"
  description = "Policy for Redstone production environment deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EKS permissions
          "eks:*",
          
          # EC2 permissions for EKS nodes
          "ec2:*",
          
          # IAM permissions for service roles
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagRole",
          "iam:UntagRole",
          
          # RDS permissions
          "rds:*",
          
          # S3 permissions
          "s3:*",
          
          # CloudWatch permissions
          "logs:*",
          "cloudwatch:*",
          
          # Application Load Balancer
          "elasticloadbalancing:*",
          
          # Route53 for DNS
          "route53:*",
          
          # Secrets Manager
          "secretsmanager:*",
          
          # Systems Manager Parameter Store
          "ssm:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          # Global services
          "iam:ListAccountAliases",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          # Prevent accidental deletion in production
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "s3:DeleteBucket"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:userid" = "*redstone-prod*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "redstone_ci_cd_policy" {
  name        = "redstone-ci-cd-policy"
  path        = "/redstone/"
  description = "Policy for Redstone CI/CD pipeline operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ECR permissions for container images
          "ecr:*",
          
          # S3 permissions for artifacts
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          
          # EKS permissions for deployments
          "eks:DescribeCluster",
          "eks:ListClusters",
          
          # Secrets Manager for deployment secrets
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          
          # CloudWatch for monitoring
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "developers_policy" {
  group      = aws_iam_group.redstone_developers.name
  policy_arn = aws_iam_policy.redstone_dev_policy.arn
}

resource "aws_iam_group_policy_attachment" "operators_policy" {
  group      = aws_iam_group.redstone_operators.name
  policy_arn = aws_iam_policy.redstone_prod_policy.arn
}

resource "aws_iam_group_policy_attachment" "ci_cd_policy" {
  group      = aws_iam_group.redstone_developers.name
  policy_arn = aws_iam_policy.redstone_ci_cd_policy.arn
}

# EKS Service Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "redstone-eks-cluster-role"
  path = "/redstone/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_role" {
  name = "redstone-eks-node-role"
  path = "/redstone/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
