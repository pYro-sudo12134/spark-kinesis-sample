variable "parameters" {
  type = map(object({
    value       = string
    type        = string
    description = optional(string, "")
  }))
}

variable "parameters_prefix_path" {
  description = "Common path prefix of all parameter names (e.g. /pipeline/localstack). Used to build the ARN prefix for GetParametersByPath scoping."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for SecureString parameters. Empty = AWS-managed aws/ssm key. Ignored for String parameters (key_id is only valid with SecureString)."
  type        = string
  default     = ""
}

variable "aws_region" { type = string }
variable "account_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}