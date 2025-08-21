# IAM Bootstrap Variables
# Following the "Built for Clarity" design philosophy

variable "aws_region" {
  description = "AWS region for IAM resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be a 12-digit number."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "redstone"
}

variable "enable_mfa_requirement" {
  description = "Require MFA for sensitive operations"
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "IAM password policy configuration"
  type = object({
    minimum_password_length        = number
    require_lowercase_characters   = bool
    require_uppercase_characters   = bool
    require_numbers               = bool
    require_symbols               = bool
    allow_users_to_change_password = bool
    max_password_age              = number
    password_reuse_prevention     = number
  })
  default = {
    minimum_password_length        = 14
    require_lowercase_characters   = true
    require_uppercase_characters   = true
    require_numbers               = true
    require_symbols               = true
    allow_users_to_change_password = true
    max_password_age              = 90
    password_reuse_prevention     = 12
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
