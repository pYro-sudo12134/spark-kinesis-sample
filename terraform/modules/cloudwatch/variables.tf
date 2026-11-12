variable "alarm_name" {
  description = "Alarm name. Referenced by the harness's alarm-state check."
  type        = string
}

variable "metric_namespace" {
  description = "Namespace the error-counter Lambda publishes to. Must match the namespace in the Lambda's policy condition, or PutMetricData is denied."
  type        = string
}

variable "metric_name" {
  description = "Metric name (e.g. ErrorObjectCreated). Must match the name the Lambda publishes."
  type        = string
}

variable "statistic" {
  description = "Statistic to apply over the period. Sum for a count of error objects."
  type        = string
  default     = "Sum"
}

variable "period_seconds" {
  description = "Alarm evaluation period, in seconds. CloudWatch accepts a fixed set of values; a value outside it fails at the alarm resource, not the variable."
  type        = number
  default     = 300

  validation {
    condition     = contains([10, 30, 60, 300, 900, 1800, 3600, 21600, 43200, 86400], var.period_seconds)
    error_message = "period_seconds must be one of CloudWatch's allowed values: 10, 30, 60, 300, 900, 1800, 3600, 21600, 43200, 86400."
  }
}

variable "evaluation_periods" {
  description = "Number of periods evaluated before the alarm changes state."
  type        = number
  default     = 1

  validation {
    condition     = var.evaluation_periods >= 1
    error_message = "evaluation_periods must be >= 1."
  }
}

variable "threshold" {
  description = "Threshold for the comparison operator. For the error-prefix alarm, >= 1 means 'any error object in the period fires'."
  type        = number
  default     = 1
}

variable "comparison_operator" {
  description = "Comparison operator, e.g. GreaterThanOrEqualToThreshold."
  type        = string
  default     = "GreaterThanOrEqualToThreshold"
}

variable "treat_missing_data" {
  description = "How to treat missing data points. notBreaching for an error counter: absence of error objects is the good case, not the alarm case."
  type        = string
  default     = "notBreaching"
}

variable "alarm_actions" {
  description = "ARNs to notify on ALARM. SNS topic ARN only in LocalStack; in aws/, other actions are possible."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}