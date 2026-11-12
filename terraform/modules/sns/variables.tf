variable "topic_name" {
  description = "Topic name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-SNS."
  type        = string
}

variable "subscription_protocol" {
  description = "SNS subscription protocol. 'sqs' locally (observable via receive-message); in aws/ this may be 'email', 'https', 'lambda', etc."
  type        = string
}

variable "subscription_endpoint" {
  description = "SNS subscription endpoint. For protocol='sqs', this is the queue ARN, not the URL."
  type        = string
}

variable "subscription_raw_delivery" {
  description = "Raw message delivery: true means the subscriber receives the alarm payload without SNS wrapping. For SQS, this is usually what you want."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}