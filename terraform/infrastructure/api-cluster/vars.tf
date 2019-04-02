variable "api_environment" {
  default     = []
  description = "A list of key-value pairs to provide to the API service as environment variables."
  type        = "list"
}

variable "api_secrets" {
  default     = []
  description = "A list of key-value pairs of secrets to provide to the API service as environment variables."
  type        = "list"
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
