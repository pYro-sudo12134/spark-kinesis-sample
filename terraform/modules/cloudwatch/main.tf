resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = var.alarm_name
  namespace           = var.metric_namespace
  metric_name         = var.metric_name
  statistic           = var.statistic
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = var.threshold
  comparison_operator = var.comparison_operator
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = var.alarm_actions
  # tags                = var.tags
}