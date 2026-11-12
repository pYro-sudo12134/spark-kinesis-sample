variable "function_name" {
  description = "Function name."
  type        = string
}

variable "handler" {
  description = "Handler entry point as '<module>.<function>', e.g. 'producer.handler'."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier. Must match the Python version build_lambdas.sh was run with — pure-Python functions work across Python 3.x, but it is wrong in principle and will fail loudly when dependencies appear."
  type        = string

  validation {
    condition     = contains(["python3.12", "python3.13"], var.runtime)
    error_message = "runtime must be one of: python3.12, python3.13 (the versions this tree is built for)."
  }
}

variable "role_arn" {
  description = "Execution role ARN. Attached by the caller via modules/iam + modules/iam_policy."
  type        = string
}

variable "filename" {
  description = "Path to the prebuilt zip. The file must exist at plan time (source_code_hash is computed from it); run scripts/build_lambdas.sh first."
  type        = string

  validation {
    condition     = endswith(lower(var.filename), ".zip")
    error_message = "filename must be a .zip path."
  }
}

variable "source_code_hash" {
  description = "Base64 SHA256 of the zip, for change detection. The caller computes it with filebase64sha256()."
  type        = string
}

variable "timeout" {
  description = "Invocation timeout in seconds. Max 900."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be in [1, 900]."
  }
}

variable "memory_size" {
  description = "Memory in MB. Max 10240."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be in [128, 10240]."
  }
}

variable "environment" {
  description = "Environment variables for the function. SSM_PREFIX and (in LocalStack) AWS_ENDPOINT_URL are set here by the caller."
  type        = map(string)
  default     = {}
}

variable "create_log_group" {
  description = "Create /aws/lambda/<name> so the role's logs:* can be scoped to this group's ARN. Disable if the group is managed elsewhere."
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "Log group retention. CloudWatch accepts a fixed set; a value outside it fails at the log group resource."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be one of CloudWatch's allowed values."
  }
}

variable "kms_key_arn_for_log_group" {
  description = "KMS key ARN for the log group, or empty for unencrypted. Empty is a valid choice for non-sensitive logs."
  type        = string
  default     = ""
}

variable "endpoint_url" {
  description = "Endpoint for the wait_active local-exec (LocalStack: the host-reachable endpoint). Empty in real AWS, where the wait is a no-op."
  type        = string
  default     = ""

  validation {
    condition     = var.endpoint_url == "" || can(regex("^https?://", var.endpoint_url))
    error_message = "endpoint_url must be empty or an http(s) URL."
  }
}

variable "kms_key_arn_for_env" {
  description = "KMS key ARN for Lambda environment-variable encryption. Empty = unencrypted. Requires the execution role to have kms:Decrypt on this key, or the function fails to start."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}