variable "admin_email" {
  default     = "admin@knowme.works"
  description = "The email address of the admin user to create."
}

variable "api_source_branch" {
  description = "The branch of the API repository to deploy."
}

variable "api_source_repo" {
  default     = "km-api"
  description = "The name of the API GitHub repository."
}

variable "apple_km_premium_product_codes" {
  description = "A comma-separated list of product codes that grant the buyer access to Know Me premium."
}

variable "apple_receipt_validation_endpoints" {
  default = {
    production = "https://buy.itunes.apple.com/verifyReceipt"
    sandbox    = "https://sandbox.itunes.apple.com/verifyReceipt"
  }

  description = "A map containing the production and sandbox endpoints for Apple's receipt validation service."
  type        = map(string)
}

variable "apple_receipt_validation_mode" {
  description = "The mode to use for validating Apple receipts. Either 'production' or 'sandbox'."
}

variable "apple_shared_secret" {
  description = "The shared secret used to validate receipts against Apple's servers."
}

variable "application_name" {
  default     = "Know Me"
  description = "The name of the application."
}

variable "application_slug" {
  default     = "km"
  description = "A base slug used when naming resources."
}

variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region to provision infrastructure in."
}

variable "domain" {
  default     = "knowmetools.com"
  description = "The root domain corresponding to a hosted zone in Route 53."
}

variable "github_organization" {
  default     = "knowmetools"
  description = "The GitHub user/organization that owns the GitHub repositories being deployed."
}

variable "sentry_dsn" {
  description = "The DSN of the Sentry project used to track errors for the API."
}

variable "web_app_source_branch" {
  description = "The branch of the web app source repository to build."
}

variable "web_app_source_repo" {
  default     = "km-web"
  description = "The name of the web app source repository."
}

