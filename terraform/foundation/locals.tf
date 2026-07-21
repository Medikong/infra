locals {
  account_id = data.aws_caller_identity.current.account_id

  terraform_state_bucket  = "${var.project_name}-terraform-state-${local.account_id}-${var.aws_region}"
  ansible_transfer_bucket = "${var.project_name}-ansible-transfer-${local.account_id}-${var.aws_region}"

  grafana_admin_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:dropmong/aws-dev/monitoring/grafana-admin-*"
  grafana_admin_secret_metadata_actions = [
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetResourcePolicy",
    "secretsmanager:ListSecretVersionIds",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "secretsmanager:UpdateSecret",
  ]
  github_oidc_subjects = [
    "repo:${var.github_repository}:ref:refs/tags/infra-aws-dev-*",
    "repo:${var.github_repository}:ref:refs/tags/infra-aws-worker-lab-*",
    "repo:${var.github_repository}:environment:${var.github_environment}",
    "repo:${var.github_repository}:environment:aws-worker-lab",
  ]

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Scope     = "foundation"
  }
}
