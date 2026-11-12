resource "aws_sns_topic" "this" {
  name              = var.topic_name
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "this" {
  topic_arn            = aws_sns_topic.this.arn
  protocol             = var.subscription_protocol
  endpoint             = var.subscription_endpoint
  raw_message_delivery = var.subscription_raw_delivery
}