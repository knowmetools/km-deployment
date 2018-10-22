variable "application_name" {
  default     = "Know Me API"
  description = "The name of the application."
}

variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region to provision infrastructure in."
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

variable "database_admin_user" {
  default     = "dbadmin"
  description = "The name of the master user account on the database."
}

variable "domain" {
  default     = "knowmetools.com"
  description = "The root domain corresponding to a hosted zone in Route 53."
}

variable "webserver_instance_type" {
  default     = "t2.micro"
  description = "The EC2 instance type to use for the webserver."
}

variable "webserver_sg_rules" {
  default     = [80, 443]
  description = "A list of allowed egress/ingress ports for webservers."
  type        = "list"
}
