output "names" { value = keys(aws_ssm_parameter.this) }
output "arns" { value = { for k, v in aws_ssm_parameter.this : k => v.arn } }

output "parameter_arn_prefix" {
  description = "ARN prefix suitable for GetParametersByPath scoping (append /* in policy Resource)."
  value       = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter${var.parameters_prefix_path}"
}