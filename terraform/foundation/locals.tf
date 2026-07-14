locals {
  account_id = data.aws_caller_identity.current.account_id

  terraform_state_bucket  = "${var.project_name}-terraform-state-${local.account_id}-${var.aws_region}"
  ansible_transfer_bucket = "${var.project_name}-ansible-transfer-${local.account_id}-${var.aws_region}"
  github_oidc_subjects = [
    "repo:${var.github_repository}:ref:refs/tags/infra-aws-dev-*",
    "repo:${var.github_repository}:environment:${var.github_environment}",
  ]

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Scope     = "foundation"
  }
}
