variable "api_environment" {
  default     = []
  description = "A list of key-value pairs to provide to the API service as environment variables."
  type        = list(object({ name = string, value = string }))
}

variable "api_secrets" {
  default     = []
  description = "A list of key-value pairs of secrets to provide to the API service as environment variables."
  type        = list(object({ name = string, valueFrom = string }))
}

variable "app_slug" {
  description = "A unique slug identifying the application."
}

variable "aws_region" {
  description = "The AWS region to provision resources in."
}

variable "certificate_arn" {
  description = "The ARN of the certificate used for HTTPS connections to the API."
}

variable "log_retention_days_api" {
  default     = 90
  description = "The number of days to keep logs for API events."
}

variable "subnet_ids" {
  description = "A list of the subnets to create cluster resources in."
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC to create the cluster in."
}

