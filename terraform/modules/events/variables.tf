variable "rule_name" {
  description = "Rule name."
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule: 'rate(N unit)' or 'cron(...)'."
  type        = string

  validation {
    condition     = can(regex("^(rate\\(.+\\)|cron\\(.+\\))$", var.schedule_expression))
    error_message = "schedule_expression must be rate(...) or cron(...)."
  }
}

variable "event_bus_name" {
  description = "Event bus name. Default bus in LocalStack; any bus in aws/."
  type        = string
  default     = "default"
}

variable "target_lambda_arn" {
  description = "Target Lambda ARN."
  type        = string
}

variable "target_lambda_name" {
  description = "Target Lambda function name (needed separately from the ARN, because the lambda permission resource takes a name)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}