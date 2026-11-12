variable "deletion_window_in_days" {
  type    = number
  default = 7
}
variable "enable_key_rotation" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "description" {
  description = "Key description; shown in IAM policy errors and KMS console."
  type        = string
}

variable "alias" {
  description = "Alias short name without the 'alias/' prefix (the module adds it). The alias is what callers reference; the key ARN is what policies reference."
  type        = string
}