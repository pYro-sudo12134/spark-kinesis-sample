output "alarm_arn" { value = aws_cloudwatch_metric_alarm.this.arn }
output "alarm_name" { value = aws_cloudwatch_metric_alarm.this.alarm_name }