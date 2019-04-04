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

variable "application_db_user" {
  default     = "app_db_user"
  description = "The name of the database user that the app connects as."
}

variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region to provision infrastructure in."
}

variable "database_admin_user" {
  default     = "dbadmin"
  description = "The name of the master user account on the database."
}

variable "database_backup_window" {
  default     = 7
  description = "The number of days to retain database backups for."
}

variable "database_instance_type" {
  default     = "db.t2.micro"
  description = "The type of database instance to provision."
}

variable "database_name" {
  default     = "appdb"
  description = "The name of the database created on the RDS instance."
}

variable "database_port" {
  default     = 5432
  description = "The port that the database is accessible on."
}

variable "database_storage" {
  default     = 10
  description = "The amount of storage (GB) to allocate for the database."
}

variable "database_user" {
  default     = "app_db_user"
  description = "The name of the database user that the application connects as."
}

variable "django_admin_email" {
  default     = "admin@knowme.works"
  description = "The email of the admin user to create."
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

