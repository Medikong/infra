output "aws_account_id" {
  description = "AWS account that owns the shared resources."
  value       = data.aws_caller_identity.current.account_id
}

output "ansible_transfer_bucket_name" {
  description = "Versioning-disabled S3 bucket used only for native Ansible SSM module transfers."
  value       = aws_s3_bucket.ansible_transfer.id
}

output "ecr_registry_url" {
  description = "Registry hostname used by GitOps image settings."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "Repository URLs keyed by service name."
  value       = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}
