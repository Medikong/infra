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

  assert {
    condition     = aws_s3_bucket.ansible_transfer.bucket == "medikong-ansible-transfer-123456789012-ap-northeast-2"
    error_message = "The Ansible transfer bucket name must be account- and region-specific."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.ansible_transfer.block_public_acls
      && aws_s3_bucket_public_access_block.ansible_transfer.block_public_policy
      && aws_s3_bucket_public_access_block.ansible_transfer.ignore_public_acls
      && aws_s3_bucket_public_access_block.ansible_transfer.restrict_public_buckets
    )
    error_message = "The Ansible transfer bucket must block every form of public access."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.ansible_transfer.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "The Ansible transfer bucket must encrypt temporary module files at rest."
  }

  assert {
    condition = (
      aws_s3_bucket_lifecycle_configuration.ansible_transfer.rule[0].expiration[0].days == 1
      && aws_s3_bucket_lifecycle_configuration.ansible_transfer.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 1
    )
    error_message = "The Ansible transfer bucket must expire objects and incomplete uploads after one day."
  }
}
