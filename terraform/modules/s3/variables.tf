variable "bucket_name" {
  description = "Name of the S3 bucket for Firehose delivery (events/) and error output (errors/)."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for default SSE-KMS on the bucket."
  type        = string
}

variable "events_prefix" {
  description = "Prefix Firehose writes successfully-delivered records under."
  type        = string
}

variable "error_prefix" {
  description = "Prefix Firehose writes rejected records under. Drives the error-counter notification."
  type        = string
}

variable "curated_prefix" {
  description = "Prefix the Spark job writes curated Parquet under. Used for lifecycle scoping only."
  type        = string
}

variable "notification_lambda_arn" {
  description = "ARN of the error-counter Lambda invoked on ObjectCreated under error_prefix."
  type        = string
}

variable "lifecycle_expire_days" {
  description = "Expire objects under events_prefix and error_prefix after N days. 0 disables the rule."
  type        = number
  default     = 0
}

variable "lifecycle_expire_curated_days" {
  description = "Expire objects under curated_prefix after N days. 0 disables the rule."
  type        = number
  default     = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}