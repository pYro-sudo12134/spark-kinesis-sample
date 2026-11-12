resource "aws_cloudwatch_log_group" "this" {
  count             = var.create_log_group ? 1 : 0
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn_for_log_group != "" ? var.kms_key_arn_for_log_group : null
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = var.filename
  source_code_hash = var.source_code_hash
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = var.environment
  }

  kms_key_arn = var.kms_key_arn_for_env != "" ? var.kms_key_arn_for_env : null

  tags       = var.tags
  depends_on = [aws_cloudwatch_log_group.this]
}