variable "app_slug" {
  description = "A unique slug identifying the application."
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

variable "domain_name" {
  description = "The domain name that the API should be accessible from."
}

variable "environment" {
  description = "The name of the current environment."
}
