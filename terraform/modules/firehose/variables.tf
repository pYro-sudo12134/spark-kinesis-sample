variable "delivery_stream_name" { type = string }
variable "kinesis_stream_arn" { type = string }
variable "kinesis_role_arn" { type = string }
variable "bucket_arn" { type = string }
variable "events_prefix" { type = string }
variable "error_prefix" { type = string }
variable "kms_key_arn" { type = string }
variable "compression_format" {
  description = "Compression for delivered objects: GZIP, Snappy, ZIP, HADOOP_SNAPPY, or UNCOMPRESSED."
  type        = string
  default     = "GZIP"

  validation {
    condition     = contains(["GZIP", "Snappy", "ZIP", "HADOOP_SNAPPY", "UNCOMPRESSED"], var.compression_format)
    error_message = "compression_format must be GZIP, Snappy, ZIP, HADOOP_SNAPPY, or UNCOMPRESSED."
  }
}
variable "buffer_size_mb" {
  type    = number
  default = 1
}
variable "buffer_interval_s" {
  type    = number
  default = 60
}
variable "tags" {
  type    = map(string)
  default = {}
}