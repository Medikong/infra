provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Scope     = "shared"
    }
  }
}

data "aws_caller_identity" "current" {}
