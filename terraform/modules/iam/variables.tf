variable "name" { type = string }

variable "trusted_service_principals" {
  description = "AWS service principals allowed to assume the role (e.g. lambda.amazonaws.com)."
  type        = list(string)
  default     = []
}

variable "trusted_account_ids" {
  description = "AWS account IDs (12-digit) whose principals may assume the role via sts:AssumeRole."
  type        = list(string)
  default     = []
}

variable "trusted_principal_arns" {
  description = "Explicit principal ARNs allowed to assume the role, in addition to trusted_account_ids."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}