# IAM Bootstrap Configuration
# Following the "Built for Clarity" design philosophy

aws_region     = "us-west-2"
aws_account_id = "238397745651"
project_name   = "redstone"

# Security settings
enable_mfa_requirement = true

# Password policy
password_policy = {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers               = true
  require_symbols               = true
  allow_users_to_change_password = true
  max_password_age              = 90
  password_reuse_prevention     = 12
}

# Additional tags
additional_tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
  Compliance = "required"
}
