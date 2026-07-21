output "environment_name" {
  description = "Resolved environment name. A named workspace takes precedence over the variable."
  value       = local.environment_name
}

output "aws_account_id" {
  description = "AWS account that owns this environment."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region for this environment."
  value       = var.aws_region
}

output "external_secrets_role_arn" {
  description = "IAM role assumed by External Secrets Operator for scoped AWS Secrets Manager access."
  value       = aws_iam_role.external_secrets.arn
}

output "grafana_external_secrets_role_arn" {
  description = "IAM role assumed by External Secrets Operator for the AWS dev Grafana break-glass secret."
  value       = aws_iam_role.external_secrets_grafana.arn
}

output "vpc_id" {
  description = "Environment VPC ID."
  value       = aws_vpc.environment.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  value       = { for availability_zone, subnet in aws_subnet.public : availability_zone => subnet.id }
}

output "kubernetes_nodes" {
  description = "Kubernetes node addresses and placement."
  value = {
    for name, instance in aws_instance.kubernetes : name => {
      availability_zone = instance.availability_zone
      instance_id       = instance.id
      instance_type     = instance.instance_type
      private_ip        = instance.private_ip
      public_ip         = instance.public_ip
      role              = local.kubernetes_nodes[name].role
      workload          = local.kubernetes_nodes[name].workload
      node_labels       = local.kubernetes_nodes[name].node_labels
      node_taints       = local.kubernetes_nodes[name].node_taints
    }
  }
}

output "managed_instance_ids" {
  description = "Space-delimited EC2 instance IDs used by the start and stop Taskfile commands."
  value       = join(" ", [for instance in values(aws_instance.kubernetes) : instance.id])
}

output "estimated_ten_day_cost" {
  description = "Static Seoul-region estimate for the configured runtime and retained gp3 capacity. KRW values include VAT; the separate reserve covers unmodeled variable costs."
  value = {
    budget_krw                = var.budget_limit_krw
    variable_reserve_krw      = var.variable_cost_reserve_krw
    modeled_ceiling_krw       = var.budget_limit_krw - var.variable_cost_reserve_krw
    exchange_rate_krw_per_usd = var.budget_exchange_rate_krw_per_usd
    vat_rate                  = var.vat_rate
    compute_usd               = tonumber(format("%.3f", local.estimated_compute_cost_usd))
    public_ipv4_usd           = tonumber(format("%.3f", local.estimated_public_ipv4_cost_usd))
    storage_usd               = tonumber(format("%.3f", local.estimated_storage_cost_usd))
    subtotal_usd              = tonumber(format("%.3f", local.estimated_total_cost_usd))
    subtotal_krw              = tonumber(format("%.2f", local.estimated_subtotal_krw))
    vat_krw                   = tonumber(format("%.2f", local.estimated_vat_krw))
    billed_cost_krw           = local.estimated_billed_cost_krw
    remaining_krw             = var.budget_limit_krw - local.estimated_billed_cost_krw
    unallocated_modeled_krw   = var.budget_limit_krw - var.variable_cost_reserve_krw - local.estimated_billed_cost_krw
    runtime_hours             = local.runtime_hours
    retained_hours            = local.calendar_hours
    runtime_days              = var.runtime_days
    retention_days            = var.retention_days
    root_volume_gib           = local.root_volume_size_gib
    total_volume_gib          = local.total_volume_size_gib
    price_publication_utc     = "2026-07-10T14:43:55Z"
    fx_reference_date         = "2026-07-10"
    fx_reference_krw_per_usd  = 1504.2
  }
}

output "control_plane_private_endpoint" {
  description = "Private Kubernetes API endpoint reached through SSM port forwarding or from inside the VPC."
  value       = "https://${aws_instance.kubernetes["control-plane-1"].private_ip}:6443"
}

output "control_plane_instance_id" {
  description = "EC2 instance ID of the single control-plane node used for SSM sessions."
  value       = aws_instance.kubernetes["control-plane-1"].id
}

output "control_plane_ssm_tunnel_command" {
  description = "SSM port-forward command that exposes the private Kubernetes API on local port 6443 without public ingress."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.kubernetes["control-plane-1"].id} --document-name AWS-StartPortForwardingSession --parameters 'portNumber=6443,localPortNumber=6443'"
}

output "ansible_inventory" {
  description = "Generated inventory content. Use the Terraform Taskfile to write it under .local/."
  value = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    aws_region                   = var.aws_region
    ansible_transfer_bucket_name = local.ansible_transfer_bucket_name
    nodes = {
      for name, instance in aws_instance.kubernetes : name => {
        instance_id = instance.id
        private_ip  = instance.private_ip
        role        = local.kubernetes_nodes[name].role
        workload    = local.kubernetes_nodes[name].workload
        node_labels = local.kubernetes_nodes[name].node_labels
        node_taints = local.kubernetes_nodes[name].node_taints
      }
    }
  })
}
