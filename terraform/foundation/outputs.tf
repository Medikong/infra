output "terraform_state_bucket" {
  description = "S3 bucket that stores all infrastructure Terraform states."
  value       = aws_s3_bucket.terraform_state.id
}

output "github_actions_role_arn" {
  description = "IAM role assumed by tagged infrastructure release workflows."
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider trusted by the deployment role."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
