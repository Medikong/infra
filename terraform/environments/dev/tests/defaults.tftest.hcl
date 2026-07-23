mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = {
      id = "i-0123456789abcdef0"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/net/medikong-dev-grafana/0123456789abcdef"
      dns_name = "medikong-dev-grafana-0123456789abcdef.elb.ap-northeast-2.amazonaws.com"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/medikong-dev-grafana/0123456789abcdef"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Action    = "sts:AssumeRole"
          Principal = { Service = "ec2.amazonaws.com" }
        }]
      })
    }
  }
}

run "dev_defaults" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "The dev VPC must use three public subnets."
  }

  assert {
    condition     = length(aws_instance.kubernetes) == 7
    error_message = "The dev Kubernetes cluster must have one control plane and six workers."
  }

  assert {
    condition = {
      for availability_zone in var.availability_zones : availability_zone =>
      length([for node in aws_instance.kubernetes : node if node.availability_zone == availability_zone])
      } == {
      (var.availability_zones[0]) = 3
      (var.availability_zones[1]) = 2
      (var.availability_zones[2]) = 2
    }
    error_message = "The seven Kubernetes nodes must place workers across all three availability zones."
  }

  assert {
    condition     = aws_instance.kubernetes["control-plane-1"].instance_type == "t4g.medium"
    error_message = "The single control-plane instance must be t4g.medium."
  }

  assert {
    condition     = aws_instance.kubernetes["worker-platform-1"].instance_type == "t4g.large"
    error_message = "The platform worker must be t4g.large for the shared cluster add-ons."
  }

  assert {
    condition = alltrue([
      for name in ["worker-app-1", "worker-app-2", "worker-data-1", "worker-data-2"] :
      aws_instance.kubernetes[name].instance_type == "t4g.medium"
    ])
    error_message = "The application and data workers must be t4g.medium."
  }

  assert {
    condition     = aws_instance.kubernetes["worker-observability-1"].instance_type == "r6g.medium"
    error_message = "The dedicated observability worker must be r6g.medium."
  }

  assert {
    condition     = strcontains(local.kubernetes_nodes["worker-observability-1"].node_labels, "medikong.io/workload=observability")
    error_message = "The observability node must carry the dedicated scheduling label passed to the generated inventory."
  }

  assert {
    condition     = local.kubernetes_nodes["worker-observability-1"].node_taints == "medikong.io/workload=observability:NoSchedule"
    error_message = "The observability worker must reject non-tolerating workloads."
  }

  assert {
    condition = (
      abs(output.estimated_ten_day_cost.subtotal_usd - 49.278) < 0.001
      && abs(output.estimated_ten_day_cost.grafana_nlb_usd - 1.620) < 0.001
    )
    error_message = "The default AWS-denominated subtotal must include USD 1.620 for the temporary Grafana NLB."
  }

  assert {
    condition = (
      output.estimated_ten_day_cost.billed_cost_krw == 86729
      && output.estimated_ten_day_cost.variable_reserve_krw == 10000
      && output.estimated_ten_day_cost.unallocated_modeled_krw == 3271
    )
    error_message = "The VAT-inclusive estimate plus KRW 10,000 reserve must remain below KRW 100,000."
  }

  assert {
    condition = (
      output.estimated_ten_day_cost.runtime_hours == 100
      && output.estimated_ten_day_cost.retained_hours == 504
      && output.estimated_ten_day_cost.grafana_nlb_retained_hours == 72
    )
    error_message = "The default budget must model 10 active days, three retained weeks, and NLB removal after 72 hours."
  }

  assert {
    condition     = output.estimated_ten_day_cost.root_volume_gib == 140 && output.estimated_ten_day_cost.total_volume_gib == 140
    error_message = "The default budget must include exactly seven 20 GiB node root volumes."
  }

  assert {
    condition = alltrue([
      for node in aws_instance.kubernetes : node.associate_public_ip_address
    ])
    error_message = "Kubernetes nodes need public IPv4 for outbound access while NAT is intentionally absent."
  }

  assert {
    condition     = aws_iam_role.external_secrets.name == "medikong-dev-external-secrets-role"
    error_message = "AWS dev must use a dedicated External Secrets role."
  }

  assert {
    condition     = aws_iam_role.external_secrets_grafana.name == "medikong-dev-external-secrets-grafana-role"
    error_message = "AWS dev Grafana must use a Secret-specific External Secrets role."
  }

  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.external_secrets_discord_webhook.policy).Statement[0].Action) == toset([
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
      ])
      && jsondecode(aws_iam_role_policy.external_secrets_discord_webhook.policy).Statement[0].Resource == "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:dropmong/aws-dev/discord/webhook-??????"
    )
    error_message = "The External Secrets role must read only the AWS dev Discord webhook secret."
  }

  assert {
    condition = (
      aws_secretsmanager_secret.grafana_admin.name == "dropmong/aws-dev/monitoring/grafana-admin"
      && aws_secretsmanager_secret.grafana_admin.recovery_window_in_days == 7
    )
    error_message = "AWS dev must manage Grafana break-glass secret metadata without storing a secret value in Terraform."
  }

}

run "reject_over_budget_runtime" {
  command = plan

  variables {
    daily_runtime_hours = 24
  }

  expect_failures = [terraform_data.budget_guard]
}

run "reject_retention_shorter_than_runtime" {
  command = plan

  variables {
    retention_days = 9
  }

  expect_failures = [terraform_data.budget_guard]
}

run "reject_unpriced_graviton_type" {
  command = plan

  variables {
    app_worker_instance_types = ["c7g.large", "t4g.medium"]
  }

  expect_failures = [terraform_data.budget_guard]
}

run "ssm_access_contract" {
  command = apply

  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.external_secrets_grafana_admin.policy).Statement[0].Action) == toset([
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
      ])
      && jsondecode(aws_iam_role_policy.external_secrets_grafana_admin.policy).Statement[0].Resource == aws_secretsmanager_secret.grafana_admin.arn
    )
    error_message = "The External Secrets role must read only the managed AWS dev Grafana admin secret."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.external_secrets_grafana.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
      && jsondecode(aws_iam_role.external_secrets_grafana.assume_role_policy).Statement[0].Principal.AWS == aws_iam_role.kubernetes_node.arn
      && jsondecode(aws_iam_role_policy.kubernetes_node_assume_external_secrets_grafana.policy).Statement[0].Action == "sts:AssumeRole"
      && jsondecode(aws_iam_role_policy.kubernetes_node_assume_external_secrets_grafana.policy).Statement[0].Resource == aws_iam_role.external_secrets_grafana.arn
    )
    error_message = "The Kubernetes node role must only assume the dedicated Grafana External Secrets role."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.external_secrets.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
      && jsondecode(aws_iam_role.external_secrets.assume_role_policy).Statement[0].Principal.AWS == aws_iam_role.kubernetes_node.arn
    )
    error_message = "Only the Kubernetes node role may assume the External Secrets role."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.kubernetes_node_assume_external_secrets.policy).Statement[0].Action == "sts:AssumeRole"
      && jsondecode(aws_iam_role_policy.kubernetes_node_assume_external_secrets.policy).Statement[0].Resource == aws_iam_role.external_secrets.arn
    )
    error_message = "The Kubernetes node role must only assume the dedicated External Secrets role."
  }

  assert {
    condition = (
      strcontains(output.ansible_inventory, "ansible_connection=amazon.aws.aws_ssm")
      && strcontains(output.ansible_inventory, "ansible_aws_ssm_instance_id=")
      && strcontains(output.ansible_inventory, "ansible_aws_ssm_timeout=900")
      && strcontains(output.ansible_inventory, "ansible_aws_ssm_bucket_name=medikong-ansible-transfer-123456789012-ap-northeast-2")
      && strcontains(output.ansible_inventory, "ansible_become_user=root")
      && !strcontains(output.ansible_inventory, "AWS-StartSSHSession")
      && !strcontains(output.ansible_inventory, "ansible_ssh_private_key_file")
      && !strcontains(output.ansible_inventory, "ansible_user=")
      && strcontains(output.control_plane_ssm_tunnel_command, "AWS-StartPortForwardingSession")
    )
    error_message = "Node administration must use the native amazon.aws.aws_ssm connection with its dedicated transfer bucket and explicit root become."
  }
}
