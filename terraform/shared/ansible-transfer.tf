locals {
  ansible_transfer_bucket = "${var.project_name}-ansible-transfer-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket" "ansible_transfer" {
  bucket        = local.ansible_transfer_bucket
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = local.ansible_transfer_bucket
    Purpose = "AnsibleSSMTransfer"
  }
}

# Do not add aws_s3_bucket_versioning here. Native aws_ssm module payloads may
# contain secrets and must not survive deletion as historical object versions.

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  rule {
    id     = "expire-ansible-transfer-files"
    status = "Enabled"

    filter {}

    expiration {
      days = var.ansible_transfer_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "ansible_transfer" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.ansible_transfer.arn,
      "${aws_s3_bucket.ansible_transfer.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id
  policy = data.aws_iam_policy_document.ansible_transfer.json
}
