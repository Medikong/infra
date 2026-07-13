variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "medikong"
}

variable "environment_name" {
  description = "Environment name used when the default Terraform workspace is selected. Named workspaces override this value."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.environment_name))
    error_message = "environment_name must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "owner" {
  description = "Team or person responsible for the environment."
  type        = string
  default     = "platform-team"
}

variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "CIDR for the environment VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Three availability zones used by the Kubernetes nodes."
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]

  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "availability_zones must contain exactly three distinct zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs in the same order as availability_zones."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.20.0/24", "10.20.30.0/24"]

  validation {
    condition = length(var.public_subnet_cidrs) == 3 && alltrue([
      for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "public_subnet_cidrs must contain exactly three valid CIDRs."
  }
}

variable "public_key_path" {
  description = "Local public key registered on Kubernetes nodes for SSH over an SSM session."
  type        = string
  default     = null
  nullable    = true
}

variable "private_key_path" {
  description = "Local private key path written to the generated Ansible inventory."
  type        = string
  default     = "~/.ssh/k8s-key"
}

variable "ubuntu_arm64_ami_ssm_parameter" {
  description = "Canonical SSM public parameter for the current Ubuntu 24.04 ARM64 AMI."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

variable "control_plane_instance_type" {
  description = "ARM instance type for the single dev control-plane node."
  type        = string
  default     = "t4g.medium"

  validation {
    condition     = can(regex("^[a-z]+[0-9]+g[a-z]*\\.", var.control_plane_instance_type))
    error_message = "control_plane_instance_type must be an AWS Graviton instance type."
  }
}

variable "platform_worker_instance_type" {
  description = "ARM instance type for the platform worker that hosts ingress and cluster add-ons."
  type        = string
  default     = "t4g.large"

  validation {
    condition     = can(regex("^[a-z]+[0-9]+g[a-z]*\\.", var.platform_worker_instance_type))
    error_message = "platform_worker_instance_type must be an AWS Graviton instance type."
  }
}

variable "app_worker_instance_types" {
  description = "ARM instance types for the two application workers."
  type        = list(string)
  default     = ["t4g.medium", "t4g.medium"]

  validation {
    condition = length(var.app_worker_instance_types) == 2 && alltrue([
      for instance_type in var.app_worker_instance_types :
      can(regex("^[a-z]+[0-9]+g[a-z]*\\.", instance_type))
    ])
    error_message = "app_worker_instance_types must contain exactly two AWS Graviton instance types."
  }
}

variable "data_worker_instance_types" {
  description = "ARM instance types for the two data workers."
  type        = list(string)
  default     = ["t4g.medium", "t4g.medium"]

  validation {
    condition = length(var.data_worker_instance_types) == 2 && alltrue([
      for instance_type in var.data_worker_instance_types :
      can(regex("^[a-z]+[0-9]+g[a-z]*\\.", instance_type))
    ])
    error_message = "data_worker_instance_types must contain exactly two AWS Graviton instance types."
  }
}

variable "observability_worker_instance_type" {
  description = "Memory-optimized ARM instance type for the dedicated observability worker."
  type        = string
  default     = "r6g.medium"

  validation {
    condition     = can(regex("^[a-z]+[0-9]+g[a-z]*\\.", var.observability_worker_instance_type))
    error_message = "observability_worker_instance_type must be an AWS Graviton instance type."
  }
}

variable "t_instance_cpu_credits" {
  description = "CPU credit mode for T-family instances. Standard avoids surplus-credit charges in dev."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.t_instance_cpu_credits)
    error_message = "t_instance_cpu_credits must be standard or unlimited."
  }
}

variable "control_plane_volume_size" {
  description = "Control-plane root volume size in GiB."
  type        = number
  default     = 20
}

variable "platform_worker_volume_size" {
  description = "Root volume size in GiB for the platform worker."
  type        = number
  default     = 20
}

variable "app_worker_volume_sizes" {
  description = "Root volume sizes in GiB for the two application workers."
  type        = list(number)
  default     = [20, 20]

  validation {
    condition = length(var.app_worker_volume_sizes) == 2 && alltrue([
      for volume_size in var.app_worker_volume_sizes : volume_size >= 8
    ])
    error_message = "app_worker_volume_sizes must contain exactly two values of at least 8 GiB."
  }
}

variable "data_worker_volume_sizes" {
  description = "Root volume sizes in GiB for the two data workers."
  type        = list(number)
  default     = [20, 20]

  validation {
    condition = length(var.data_worker_volume_sizes) == 2 && alltrue([
      for volume_size in var.data_worker_volume_sizes : volume_size >= 8
    ])
    error_message = "data_worker_volume_sizes must contain exactly two values of at least 8 GiB."
  }
}

variable "observability_worker_volume_size" {
  description = "Root volume size in GiB for the dedicated observability worker. Dev telemetry stays on node-local storage."
  type        = number
  default     = 20
}

variable "budget_limit_krw" {
  description = "Maximum VAT-inclusive AWS bill for one dev workspace."
  type        = number
  default     = 100000

  validation {
    condition     = var.budget_limit_krw > 0
    error_message = "budget_limit_krw must be greater than zero."
  }
}

variable "budget_exchange_rate_krw_per_usd" {
  description = "Conservative fixed exchange rate used to convert the USD service estimate into KRW."
  type        = number
  default     = 1600

  validation {
    condition     = var.budget_exchange_rate_krw_per_usd > 0
    error_message = "budget_exchange_rate_krw_per_usd must be greater than zero."
  }
}

variable "vat_rate" {
  description = "VAT rate applied to the converted AWS service estimate."
  type        = number
  default     = 0.10

  validation {
    condition     = var.vat_rate >= 0 && var.vat_rate < 1
    error_message = "vat_rate must be at least zero and lower than one."
  }
}

variable "variable_cost_reserve_krw" {
  description = "VAT-inclusive KRW reserve for transfer, ECR, snapshots, and exchange-rate drift."
  type        = number
  default     = 10000

  validation {
    condition     = var.variable_cost_reserve_krw >= 0
    error_message = "variable_cost_reserve_krw must be zero or greater."
  }
}

variable "daily_runtime_hours" {
  description = "Expected EC2 runtime per day. Stop the instances outside this window."
  type        = number
  default     = 10

  validation {
    condition     = var.daily_runtime_hours > 0 && var.daily_runtime_hours <= 24
    error_message = "daily_runtime_hours must be greater than zero and no more than 24."
  }
}

variable "runtime_days" {
  description = "Number of days in the short-lived dev environment cost window."
  type        = number
  default     = 10

  validation {
    condition     = var.runtime_days > 0 && var.runtime_days <= 31
    error_message = "runtime_days must be greater than zero and no more than 31."
  }
}

variable "retention_days" {
  description = "Calendar days that retained EC2 root volumes remain allocated."
  type        = number
  default     = 21

  validation {
    condition     = var.retention_days > 0 && var.retention_days <= 31
    error_message = "retention_days must be greater than zero and no more than 31."
  }
}

variable "root_volume_kms_key_id" {
  description = "Optional KMS key ID or ARN for encrypted EC2 root volumes. Null uses the account default EBS key."
  type        = string
  default     = null
  nullable    = true
}
