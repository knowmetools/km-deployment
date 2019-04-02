variable "app_slug" {
  description = "A unique slug identifying the application."
}

variable "apple_km_premium_product_codes" {
  description = "A comma-separated list of product codes that grant the buyer access to Know Me premium."
}

variable "apple_receipt_validation_endpoint" {
  description = "The endpoint to use for validating Apple receipts."
}

variable "apple_shared_secret" {
  description = "The shared secret used when validating Apple receipts."
}

variable "certificate_arn" {
  description = "The ARN of the certificate used for HTTPS connections to the API."
}

variable "db_host" {
  description = "The hostname of the database to connect to."
}

variable "db_name" {
  description = "The name of the database to connect to."
}

variable "db_password_ssm_arn" {
  description = "The name of the SSM parameter containing the password to the database."
}

variable "db_port" {
  default     = "5432"
  description = "The port to connect to the database over."
}

variable "db_user" {
  description = "The name of the database user to connect as."
}

variable "django_secret_key_ssm_arn" {
  description = "The ARN of the SSM parameter containing the secret key to use for the application."
}

variable "domain_name" {
  description = "The domain name that the API should be accessible from."
}

variable "email_verification_url" {
  description = "The URL template for sending email verification links."
}

variable "environment" {
  description = "The name of the current environment."
}

variable "password_reset_url" {
  description = "The URL template used to construct password reset links."
}

variable "sentry_dsn" {
  description = "The DSN of the Sentry project that errors in the API are reported to."
}

variable "static_s3_bucket" {
  description = "The name of the S3 bucket to store static files in."
}
