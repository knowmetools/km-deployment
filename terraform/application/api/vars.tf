variable "acm_certificate" {
  description = "The ACM certificate used for SSL traffic to the API."
  type        = object({ arn = string })
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

variable "application_db_user" {
  default     = "app_db_user"
  description = "The name of the database user that the app connects as."
}

variable "base_tags" {
  default     = {}
  description = "A set of base tags to apply to all taggable resources."
  type        = map(string)
}

variable "database_name" {
  default     = "appdb"
  description = "The name of the database to store information in."
}

variable "domain" {
  description = "The domain name that the API is accessible from."
}

variable "environment" {
  description = "The name of the current environment."
}

variable "sentry_dsn" {
  description = "The DSN of the Sentry project used to track errors for the API."
}

variable "ssm_parameter_prefix" {
  description = "A prefix to apply to SSM parameters."
}

variable "subnet_ids" {
  description = "A list containing the IDs of the subnets that the API can be run in."
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC to create resources in."
}

variable "web_app_domain" {
  description = "The domain of the web app tied to this API environment."
}
