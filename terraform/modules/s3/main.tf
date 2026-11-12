resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  raw_prefixes = [
    for p in [var.events_prefix, var.error_prefix] : p if var.lifecycle_expire_days > 0
  ]
  curated_rules = var.lifecycle_expire_curated_days > 0 ? [var.curated_prefix] : []
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = local.raw_prefixes
    content {
      id     = "expire-${replace(rule.value, "/", "-")}"
      status = "Enabled"

      filter {
        prefix = rule.value
      }

      expiration {
        days = var.lifecycle_expire_days
      }
    }
  }

  dynamic "rule" {
    for_each = local.curated_rules
    content {
      id     = "expire-${replace(rule.value, "/", "-")}"
      status = "Enabled"

      filter {
        prefix = rule.value
      }

      expiration {
        days = var.lifecycle_expire_curated_days
      }
    }
  }
}

resource "aws_s3_bucket_notification" "errors" {
  bucket = aws_s3_bucket.this.id

  lambda_function {
    lambda_function_arn = var.notification_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.error_prefix
  }

  depends_on = [aws_s3_bucket.this]
}