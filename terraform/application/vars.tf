variable "api_acm_certificate" {
  description = "The ACM certificate to use for SSL traffic to the API."
  type        = object({ arn = string })
}

variable "api_domain" {
  description = "The domain name that the API is accessible through."
}

variable "app_name" {
  description = "A human readable name for the application."
}

variable "app_slug" {
  description = "A slugified version of the application's name."
}

variable "apple_km_premium_product_codes" {
  description = "A comma-separated list of product codes that grant the buyer access to Know Me premium."
}

variable "apple_receipt_validation_endpoint" {
  description = "The endpoint to use when validating Apple receipts."
}

variable "apple_shared_secret" {
  description = "The shared secret used to validate receipts against Apple's servers."
}

variable "base_tags" {
  default     = {}
  description = "A set of base tags to apply to all taggable resources."
  type        = map(string)
}

variable "environment" {
  description = "The name of the current environment."
}

variable "route_53_zone" {
  description = "The Route53 zone to create DNS records in."
  type        = object({ id = string })
}

variable "sentry_dsn" {
  description = "The DSN of the Sentry project used to track errors for the API."
}

variable "ssm_parameter_prefix" {
  description = "A prefix to apply to SSM parameters."
}

variable "web_app_acm_certificate" {
  description = "The ACM certificate to use for the web app."
  type        = object({ arn = string })
}

variable "web_app_domain" {
  description = "The domain that the web app is accessible at."
}
