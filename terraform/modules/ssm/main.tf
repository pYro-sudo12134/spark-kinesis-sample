resource "aws_ssm_parameter" "this" {
  for_each    = var.parameters
  name        = each.key
  value       = each.value.value
  type        = each.value.type
  description = each.value.description
  key_id      = each.value.type == "SecureString" && var.kms_key_arn != "" ? var.kms_key_arn : null
  tags        = var.tags
}