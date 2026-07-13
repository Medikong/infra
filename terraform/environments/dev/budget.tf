locals {
  # AWS Price List, ap-northeast-2, publication 2026-07-10T14:43:55Z:
  # https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/20260710144355/ap-northeast-2/index.json
  # Refresh this table and the README before relying on the estimate later.
  instance_hourly_price_usd = {
    "t4g.micro"  = 0.0104
    "t4g.small"  = 0.0208
    "t4g.medium" = 0.0416
    "t4g.large"  = 0.0832
    "r6g.medium" = 0.0610
    "r6g.large"  = 0.1220
  }

  gp3_gib_month_price_usd    = 0.0912
  public_ipv4_hour_price_usd = 0.005
  price_month_hours          = 720

  runtime_hours  = var.daily_runtime_hours * var.runtime_days
  calendar_hours = var.retention_days * 24

  estimated_instance_types = [for node in values(local.kubernetes_nodes) : node.instance_type]

  root_volume_size_gib = sum([
    for node in values(local.kubernetes_nodes) : node.volume_size
  ])
  total_volume_size_gib = local.root_volume_size_gib

  estimated_compute_cost_usd = sum([
    for instance_type in local.estimated_instance_types :
    lookup(local.instance_hourly_price_usd, instance_type, 0) * local.runtime_hours
  ])
  estimated_public_ipv4_cost_usd = length(local.kubernetes_nodes) * local.runtime_hours * local.public_ipv4_hour_price_usd
  estimated_storage_cost_usd = (
    local.total_volume_size_gib
    * local.gp3_gib_month_price_usd
    * local.calendar_hours
    / local.price_month_hours
  )
  estimated_total_cost_usd = (
    local.estimated_compute_cost_usd
    + local.estimated_public_ipv4_cost_usd
    + local.estimated_storage_cost_usd
  )

  estimated_subtotal_krw = (
    local.estimated_total_cost_usd
    * var.budget_exchange_rate_krw_per_usd
  )
  estimated_vat_krw = local.estimated_subtotal_krw * var.vat_rate
  estimated_billed_cost_krw = ceil(
    local.estimated_subtotal_krw + local.estimated_vat_krw
  )
}

resource "terraform_data" "budget_guard" {
  input = local.estimated_billed_cost_krw

  lifecycle {
    precondition {
      condition = alltrue([
        for instance_type in local.estimated_instance_types :
        contains(keys(local.instance_hourly_price_usd), instance_type)
      ])
      error_message = "The selected instance type is missing from the dev cost model. Add a verified ap-northeast-2 price before planning."
    }

    precondition {
      condition     = var.variable_cost_reserve_krw < var.budget_limit_krw
      error_message = "variable_cost_reserve_krw must be lower than budget_limit_krw."
    }

    precondition {
      condition     = var.retention_days >= var.runtime_days
      error_message = "retention_days must be greater than or equal to runtime_days."
    }

    precondition {
      condition     = local.estimated_billed_cost_krw <= var.budget_limit_krw - var.variable_cost_reserve_krw
      error_message = "The VAT-inclusive KRW estimate consumes the variable-cost reserve. Reduce runtime, instance sizes, or gp3 capacity."
    }
  }
}
