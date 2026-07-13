variable "project_name" {
  description = "Project name used in tags."
  type        = string
  default     = "medikong"
}

variable "aws_region" {
  description = "AWS region for shared resources."
  type        = string
  default     = "ap-northeast-2"
}

variable "ecr_repositories" {
  description = "Service image repositories shared by all deployment environments."
  type        = set(string)
  default = [
    "auth-service",
    "backoffice-service",
    "coupon-service",
    "concert-service",
    "dashboard",
    "frontend",
    "notification-service",
    "payment-service",
    "read-api-loadtest",
    "reservation-service",
    "synthetic-traffic",
    "ticket-service",
    "user-service",
  ]
}

variable "ecr_image_tag_mutability" {
  description = "Whether ECR image tags can be overwritten."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}
