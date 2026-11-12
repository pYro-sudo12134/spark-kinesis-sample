resource "aws_cloudwatch_event_rule" "this" {
  name                = var.rule_name
  schedule_expression = var.schedule_expression
  event_bus_name      = var.event_bus_name
  state               = "ENABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "this" {
  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = var.event_bus_name
  target_id      = "canary-lambda"
  arn            = var.target_lambda_arn
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}