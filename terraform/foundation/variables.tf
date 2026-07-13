variable "project_name" {
  description = "Project name used for foundation resources and tags."
  type        = string
  default     = "medikong"
}

variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "ap-northeast-2"
}

variable "github_repository" {
  description = "GitHub repository allowed to request AWS deployment credentials."
  type        = string
  default     = "Medikong/infra"
}

variable "github_environment" {
  description = "GitHub Environment allowed to apply AWS development infrastructure."
  type        = string
  default     = "aws-dev"
}

variable "github_actions_role_name" {
  description = "IAM role assumed by the infrastructure release workflow."
  type        = string
  default     = "medikong-github-infra-deployer"
}

variable "github_actions_role_max_session_seconds" {
  description = "Maximum GitHub Actions deployment session duration."
  type        = number
  default     = 7200

  validation {
    condition = (
      var.github_actions_role_max_session_seconds >= 3600
      && var.github_actions_role_max_session_seconds <= 43200
    )
    error_message = "github_actions_role_max_session_seconds must be between 3600 and 43200."
  }
}
