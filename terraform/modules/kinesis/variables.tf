variable "stream_name" {
  description = "Stream name. Unique within the account/region."
  type        = string
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

variable "shard_count" {
  description = "Number of shards when stream_mode = PROVISIONED. Must be null for ON_DEMAND — the resource would reject a non-null value, but the error names the stream, not the variable."
  type        = number
  default     = 1

  validation {
    condition     = var.shard_count == null || var.shard_count >= 1
    error_message = "shard_count must be null or >= 1."
  }

  validation {
    condition     = !(var.stream_mode == "ON_DEMAND" && var.shard_count != null)
    error_message = "shard_count must be null when stream_mode is ON_DEMAND."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for Kinesis SSE. Reading an encrypted stream (Firehose) requires kms:Decrypt on this key in the reader's role."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}