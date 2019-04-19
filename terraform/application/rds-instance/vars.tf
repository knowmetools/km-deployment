variable "admin_user" {
  default     = "dbadmin"
  description = "The name of the admin user to create for the instance."
}

variable "allow_major_version_upgrade" {
  default     = false
  description = "A boolean indicating if major version upgrades should be applied automatically."
}

variable "backup_retention_period" {
  default     = 7
  description = "The number of days to retain backups for."
}

variable "base_tags" {
  default     = {}
  description = "A base set of tags to apply to all taggable resources."
  type        = map(string)
}

variable "db_name" {
  description = "The name of the database to create on the instance."
}

variable "engine" {
  default     = "postgres"
  description = "The database engine to run on the instance."
}

variable "iam_database_authentication_enabled" {
  default     = false
  description = "A boolean indicating if authentication via IAM roles should be enabled."
}

variable "instance_type" {
  default     = "db.t2.micro"
  description = "The instance type to use for the database."
}

variable "name" {
  description = "A human readable name for the database."
}

variable "name_slug" {
  description = "A slug identifying the database."
}

variable "port" {
  default     = 5432
  description = "The port to make the database accessible over."
}

variable "storage_gb" {
  default     = 10
  description = "The amount of storage (in GB) to allocate for the instance."
}
