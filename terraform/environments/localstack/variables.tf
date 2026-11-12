variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

variable "aws_endpoint" { type = string }
variable "aws_s3_endpoint" { type = string }

variable "trusted_account_ids" {
  description = "Account IDs permitted to assume account-principal roles (the Spark reader role)."
  type        = list(string)
}
variable "spark_trusted_principal_arns" {
  description = "Additional principal ARNs allowed to assume the Spark role."
  type        = list(string)
  default     = []
}

variable "lifecycle_expire_days" {
  description = "Expire objects under the raw (events/ and errors/) prefixes after N days. 0 disables expiry."
  type        = number
  default     = 0
}

variable "lifecycle_expire_curated_days" {
  description = "Expire objects under the curated prefix after N days. 0 disables expiry."
  type        = number
  default     = 0
}

variable "curated_prefix" {
  description = "Prefix under which the Spark job writes curated Parquet. Used for lifecycle scoping only."
  type        = string
}

variable "iceberg_warehouse_prefix" {
  description = "S3 prefix for the Iceberg Hadoop catalog warehouse. Must end with '/': the Spark role's PutObject scope is '$${bucket_arn}/$${prefix}*', and a missing slash silently changes the scope."
  type        = string

  validation {
    condition     = endswith(var.iceberg_warehouse_prefix, "/")
    error_message = "iceberg_warehouse_prefix must end with '/' (e.g. \"warehouse/\")."
  }
}

variable "stream_mode" {
  description = "PROVISIONED (explicit shard_count) or ON_DEMAND (no shard_count). The two are mutually exclusive at the resource level; validating here turns a confusing Kinesis error into a clear plan-time error."
  type        = string
  default     = "PROVISIONED"

  validation {
    condition     = contains(["PROVISIONED", "ON_DEMAND"], var.stream_mode)
    error_message = "stream_mode must be PROVISIONED or ON_DEMAND."
  }
}

variable "localstack_endpoint_from_container" { type = string }

variable "bucket_name" { type = string }
variable "events_prefix" { type = string }
variable "error_prefix" { type = string }
variable "stream_name" { type = string }
variable "stream_shard_count" { type = number }
variable "delivery_stream_name" { type = string }
variable "firehose_buffer_size_mb" { type = number }
variable "firehose_buffer_interval_s" { type = number }

variable "canary_function_name" { type = string }
variable "error_counter_function_name" { type = string }
variable "lambda_runtime" { type = string }
variable "lambda_timeout_seconds" { type = number }
variable "lambda_memory_mb" { type = number }
variable "lambda_log_retention_days" { type = number }

variable "canary_rule_name" { type = string }
variable "canary_schedule" { type = string }
variable "event_bus_name" { type = string }

variable "metric_namespace" { type = string }
variable "error_metric_name" { type = string }
variable "alarm_name" { type = string }
variable "alarm_threshold" { type = number }
variable "alarm_period_seconds" { type = number }
variable "alarm_eval_periods" { type = number }

variable "alarm_topic_name" { type = string }
variable "alarm_queue_name" { type = string }

variable "kms_alias" { type = string }
variable "ssm_prefix" { type = string }

variable "tags" { type = map(string) }