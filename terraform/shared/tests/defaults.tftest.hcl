mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "shared_defaults" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.service) == 13
    error_message = "The shared stack must create one ECR repository for each configured service."
  }

  assert {
    condition = alltrue([
      for repository in aws_ecr_repository.service : repository.image_tag_mutability == "IMMUTABLE"
    ])
    error_message = "Shared ECR repositories must use immutable tags by default."
  }
}
