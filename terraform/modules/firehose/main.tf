resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.delivery_stream_name
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = var.kinesis_stream_arn
    role_arn           = var.kinesis_role_arn
  }

  extended_s3_configuration {
    role_arn            = var.kinesis_role_arn
    bucket_arn          = var.bucket_arn
    prefix              = var.events_prefix
    error_output_prefix = var.error_prefix
    buffering_size      = var.buffer_size_mb
    buffering_interval  = var.buffer_interval_s
    compression_format  = var.compression_format
    kms_key_arn         = var.kms_key_arn
  }

  tags = var.tags
}