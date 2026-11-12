terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws", version = ">= 5.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.4" }
    null    = { source = "hashicorp/null", version = ">= 3.2" }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = var.aws_access_key
  secret_key                  = var.aws_secret_key
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = false

  endpoints {
    s3         = var.aws_s3_endpoint
    kinesis    = var.aws_endpoint
    firehose   = var.aws_endpoint
    lambda     = var.aws_endpoint
    events     = var.aws_endpoint
    cloudwatch = var.aws_endpoint
    logs       = var.aws_endpoint
    sns        = var.aws_endpoint
    sqs        = var.aws_endpoint
    iam        = var.aws_endpoint
    sts        = var.aws_endpoint
    ssm        = var.aws_endpoint
    kms        = var.aws_endpoint
  }
}

locals {
  s3_bucket_arn      = module.s3.bucket_arn
  kinesis_stream_arn = module.kinesis.stream_arn
  kms_key_arn        = module.kms.key_arn
  sqs_queue_arn      = module.sqs.queue_arn

  ssm_parameter_arn_prefix           = module.ssm.parameter_arn_prefix
  canary_log_group_arn_prefix        = module.lambda_canary.log_group_arn
  error_counter_log_group_arn_prefix = module.lambda_error_counter.log_group_arn
}

module "kms" {
  source      = "../../modules/kms"
  description = "Pipeline SSE key (${var.tags.Env})"
  alias       = var.kms_alias
  tags        = var.tags
}

module "role_firehose" {
  source                     = "../../modules/iam"
  name                       = "firehose-delivery"
  trusted_service_principals = ["firehose.amazonaws.com"]
  tags                       = var.tags
}

module "role_canary" {
  source                     = "../../modules/iam"
  name                       = "canary-producer"
  trusted_service_principals = ["lambda.amazonaws.com"]
  tags                       = var.tags
}

module "role_error_counter" {
  source                     = "../../modules/iam"
  name                       = "firehose-error-counter"
  trusted_service_principals = ["lambda.amazonaws.com"]
  tags                       = var.tags
}

module "role_spark" {
  source                 = "../../modules/iam"
  name                   = "spark-reader"
  trusted_account_ids    = var.trusted_account_ids
  trusted_principal_arns = var.spark_trusted_principal_arns
  tags                   = var.tags
}

module "ssm" {
  source                 = "../../modules/ssm"
  parameters_prefix_path = var.ssm_prefix
  aws_region             = var.aws_region
  account_id             = var.account_id
  kms_key_arn = module.kms.key_arn
  tags                   = var.tags
  parameters = {
    "${var.ssm_prefix}/bucket_name"          = { value = var.bucket_name, type = "String" }
    "${var.ssm_prefix}/events_prefix"        = { value = var.events_prefix, type = "String" }
    "${var.ssm_prefix}/error_prefix"         = { value = var.error_prefix, type = "String" }
    "${var.ssm_prefix}/curated_prefix"       = { value = var.curated_prefix, type = "String" }
    "${var.ssm_prefix}/stream_name"          = { value = var.stream_name, type = "String" }
    "${var.ssm_prefix}/delivery_stream_name" = { value = var.delivery_stream_name, type = "String" }
    "${var.ssm_prefix}/metric_namespace"     = { value = var.metric_namespace, type = "String" }
    "${var.ssm_prefix}/error_metric_name"    = { value = var.error_metric_name, type = "String" }
    "${var.ssm_prefix}/spark_role_arn"       = { value = module.role_spark.role_arn, type = "String" }
    "${var.ssm_prefix}/kms_key_arn"          = { value = module.kms.key_arn, type = "String" }
    "${var.ssm_prefix}/region"               = { value = var.aws_region, type = "String" }
    "${var.ssm_prefix}/account_id"           = { value = var.account_id, type = "String" }
    "${var.ssm_prefix}/curated_prefix"       = { value = var.curated_prefix, type = "String" }
    "${var.ssm_prefix}/iceberg_warehouse"    = { value = "s3a://${var.bucket_name}/${var.iceberg_warehouse_prefix}", type = "String" }
  }
}

module "s3" {
  source                        = "../../modules/s3"
  bucket_name                   = var.bucket_name
  kms_key_arn                   = module.kms.key_arn
  events_prefix                 = var.events_prefix
  error_prefix                  = var.error_prefix
  curated_prefix                = var.curated_prefix
  lifecycle_expire_days         = var.lifecycle_expire_days
  lifecycle_expire_curated_days = var.lifecycle_expire_curated_days
  notification_lambda_arn       = module.lambda_error_counter.function_arn
  tags                          = var.tags
}

module "kinesis" {
  source      = "../../modules/kinesis"
  stream_name = var.stream_name
  shard_count = var.stream_shard_count
  stream_mode = var.stream_mode
  kms_key_arn = module.kms.key_arn
  tags        = var.tags
}

module "firehose" {
  source               = "../../modules/firehose"
  delivery_stream_name = var.delivery_stream_name
  kinesis_stream_arn   = module.kinesis.stream_arn
  kinesis_role_arn     = module.role_firehose.role_arn
  bucket_arn           = module.s3.bucket_arn
  events_prefix        = var.events_prefix
  error_prefix         = var.error_prefix
  kms_key_arn          = module.kms.key_arn
  buffer_size_mb       = var.firehose_buffer_size_mb
  buffer_interval_s    = var.firehose_buffer_interval_s
  tags                 = var.tags
}

module "sqs" {
  source      = "../../modules/sqs"
  queue_name  = var.alarm_queue_name
  kms_key_arn = module.kms.key_arn
  tags        = var.tags
}

module "sns" {
  source                    = "../../modules/sns"
  topic_name                = var.alarm_topic_name
  kms_key_arn               = module.kms.key_arn
  subscription_protocol     = "sqs"
  subscription_endpoint     = module.sqs.queue_arn
  subscription_raw_delivery = true
  tags                      = var.tags
}

module "cloudwatch" {
  source             = "../../modules/cloudwatch"
  alarm_name         = var.alarm_name
  metric_namespace   = var.metric_namespace
  metric_name        = var.error_metric_name
  period_seconds     = var.alarm_period_seconds
  evaluation_periods = var.alarm_eval_periods
  threshold          = var.alarm_threshold
  alarm_actions      = [module.sns.topic_arn]
  tags               = var.tags
}

module "lambda_canary" {
  source           = "../../modules/lambda"
  function_name    = var.canary_function_name
  handler          = "producer.handler"
  runtime          = var.lambda_runtime
  role_arn         = module.role_canary.role_arn
  filename         = "${path.root}/../../../build/canary.zip"
  source_code_hash = filebase64sha256("${path.root}/../../../build/canary.zip")
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb
  environment = {
    SSM_PREFIX       = var.ssm_prefix
    AWS_ENDPOINT_URL = var.localstack_endpoint_from_container
  }
  log_retention_in_days     = var.lambda_log_retention_days
  kms_key_arn_for_log_group = module.kms.key_arn
  kms_key_arn_for_env = module.kms.key_arn
  tags                      = var.tags
}

module "lambda_error_counter" {
  source           = "../../modules/lambda"
  function_name    = var.error_counter_function_name
  handler          = "counter.handler"
  runtime          = var.lambda_runtime
  role_arn         = module.role_error_counter.role_arn
  filename         = "${path.root}/../../../build/error_counter.zip"
  source_code_hash = filebase64sha256("${path.root}/../../../build/error_counter.zip")
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb
  environment = {
    SSM_PREFIX       = var.ssm_prefix
    AWS_ENDPOINT_URL = var.localstack_endpoint_from_container
  }
  log_retention_in_days     = var.lambda_log_retention_days
  kms_key_arn_for_log_group = module.kms.key_arn
  kms_key_arn_for_env = module.kms.key_arn
  tags                      = var.tags
}

module "events" {
  source              = "../../modules/events"
  rule_name           = var.canary_rule_name
  schedule_expression = var.canary_schedule
  event_bus_name      = var.event_bus_name
  target_lambda_arn   = module.lambda_canary.function_arn
  target_lambda_name  = module.lambda_canary.function_name
  tags                = var.tags
}

resource "aws_lambda_permission" "s3_invoke_error_counter" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_error_counter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3.bucket_arn
}

module "iam_policy_firehose" {
  source    = "../../modules/iam_policy"
  name      = "firehose-delivery-policy"
  role_name = module.role_firehose.role_name
  tags      = var.tags
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kinesis:DescribeStream", "kinesis:DescribeStreamSummary", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
        Resource = local.kinesis_stream_arn
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = [
          "${local.s3_bucket_arn}/${var.events_prefix}*",
          "${local.s3_bucket_arn}/${var.error_prefix}*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = local.s3_bucket_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = local.kms_key_arn
      },
    ]
  })
}

module "iam_policy_canary" {
  source    = "../../modules/iam_policy"
  name      = "canary-producer-policy"
  role_name = module.role_canary.role_name
  tags      = var.tags
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = local.kinesis_stream_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
        Resource = "${local.ssm_parameter_arn_prefix}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${local.canary_log_group_arn_prefix}:log-stream:*"
      },
    ]
  })
}

module "iam_policy_error_counter" {
  source    = "../../modules/iam_policy"
  name      = "firehose-error-counter-policy"
  role_name = module.role_error_counter.role_name
  tags      = var.tags
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["cloudwatch:PutMetricData"]
        Resource  = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = var.metric_namespace } }
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
        Resource = "${local.ssm_parameter_arn_prefix}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${local.error_counter_log_group_arn_prefix}:log-stream:*"
      },
    ]
  })
}

module "iam_policy_spark" {
  source    = "../../modules/iam_policy"
  name      = "spark-reader-policy"
  role_name = module.role_spark.role_name
  tags      = var.tags
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${local.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = [
          "${local.s3_bucket_arn}/${var.curated_prefix}*",
          "${local.s3_bucket_arn}/${var.iceberg_warehouse_prefix}*",
        ]
      },
      {
        Effect    = "Allow"
        Action    = ["s3:ListBucket"]
        Resource  = local.s3_bucket_arn
        Condition = { StringLike = { "s3:prefix" = [var.events_prefix, var.error_prefix, var.curated_prefix] } }
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = local.kms_key_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
        Resource = "${local.ssm_parameter_arn_prefix}/*"
      },
    ]
  })
}