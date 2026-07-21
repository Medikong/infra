mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version   = "2012-10-17"
        Statement = []
      })
    }
  }
}

run "foundation_defaults" {
  command = plan

  assert {
    condition     = aws_s3_bucket.terraform_state.bucket == "medikong-terraform-state-123456789012-ap-northeast-2"
    error_message = "The foundation stack must derive one account- and region-specific state bucket name."
  }

  assert {
    condition     = aws_s3_bucket_versioning.terraform_state.versioning_configuration[0].status == "Enabled"
    error_message = "Terraform state bucket versioning must be enabled."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.terraform_state.block_public_acls
      && aws_s3_bucket_public_access_block.terraform_state.block_public_policy
      && aws_s3_bucket_public_access_block.terraform_state.ignore_public_acls
      && aws_s3_bucket_public_access_block.terraform_state.restrict_public_buckets
    )
    error_message = "The Terraform state bucket must block every form of public access."
  }

  assert {
    condition     = aws_iam_role.github_actions.max_session_duration == 7200
    error_message = "The GitHub deployment role must support the two-hour release job."
  }

  assert {
    condition = (
      aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
      && aws_iam_openid_connect_provider.github_actions.client_id_list == toset(["sts.amazonaws.com"])
    )
    error_message = "The foundation stack must create the GitHub Actions OIDC provider for AWS STS."
  }

  assert {
    condition = local.github_oidc_subjects == [
      "repo:Medikong/infra:ref:refs/tags/infra-aws-dev-*",
      "repo:Medikong/infra:environment:aws-dev",
    ]
    error_message = "The GitHub deployment role must trust only infrastructure tags and the aws-dev environment."
  }

  assert {
    condition     = local.ansible_transfer_bucket == "medikong-ansible-transfer-123456789012-ap-northeast-2"
    error_message = "The GitHub deployment role and shared stack must use the same account- and region-specific Ansible transfer bucket name."
  }

  assert {
    condition = (
      local.grafana_admin_secret_arn == "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:dropmong/aws-dev/monitoring/grafana-admin-*"
      && toset(local.grafana_admin_secret_metadata_actions) == toset([
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:UpdateSecret",
      ])
      && !contains(local.grafana_admin_secret_metadata_actions, "secretsmanager:GetSecretValue")
    )
    error_message = "The GitHub deployment role must manage only Grafana secret metadata and must not read the secret value."
  }
}
