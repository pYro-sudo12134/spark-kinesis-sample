variable "name" {
  description = "Policy name. Distinct from the role name; the role-policy relationship is many-to-many in principle."
  type        = string
}

variable "policy_json" {
  description = "Policy document as JSON. Must include Version and Statement."
  type        = string
}

variable "role_name" {
  description = "Name of the role to attach to. A name, not an ARN; the attachment resource resolves it."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}