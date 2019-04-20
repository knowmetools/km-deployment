variable "admin_email" {
  description = "The email address of the application admin user."
}

variable "api_prod" {
  description = "An object describing the production API to deploy to."
  type = object({
    database_admin_password_ssm_param = object({ arn = string, name = string })
    database_admin_user               = string
    ecs_cluster                       = string
    ecs_service                       = string
    lb_listener_arn                   = string
    lb_target_group_1                 = string
    lb_target_group_2                 = string
    migration_security_group_ids      = list(string)
    migration_subnet_ids              = list(string)
    task_definition_content           = string
    task_definition_family            = string
    url                               = string
    web_container_name                = string
    web_container_port                = string
  })
}

variable "api_staging" {
  description = "An object describing the staging API to deploy to."
  type = object({
    database_admin_password_ssm_param = object({ arn = string, name = string })
    database_admin_user               = string
    ecs_cluster                       = string
    ecs_service                       = string
    lb_listener_arn                   = string
    lb_target_group_1                 = string
    lb_target_group_2                 = string
    migration_security_group_ids      = list(string)
    migration_subnet_ids              = list(string)
    task_definition_content           = string
    task_definition_family            = string
    url                               = string
    web_container_name                = string
    web_container_port                = string
  })
}

variable "api_source_branch" {
  description = "The branch of the API source repository to build."
}

variable "api_source_repo" {
  description = "The name of the API source repository."
}

variable "api_task_definition_image_placeholder" {
  description = "The placeholder value in the API task definition that is replaced with a Docker image version."
}

variable "app_name" {
  description = "A human readable name for the application."
}

variable "app_slug" {
  description = "A slugified version of the application's name."
}

variable "base_tags" {
  default     = {}
  description = "A base set of tags to apply to all taggable resources."
  type        = map(string)
}

variable "log_retention_days" {
  default     = 30
  description = "The number of days that logs related to deployments should be retained for."
}

variable "source_owner" {
  description = "The name of the GitHub organization that owns the source repositories for the API and web app."
}

variable "ssm_parameter_prefix" {
  description = "A prefix to apply to SSM parameters."
}

variable "web_app_prod" {
  description = "An object describing the production web app to deploy to."
  type = object({
    s3_bucket = object({ bucket = string, arn = string })
  })
}

variable "web_app_source_branch" {
  description = "The branch of the web app repository to build."
}

variable "web_app_source_repo" {
  description = "The name of the web app source repository."
}

variable "web_app_staging" {
  description = "An object describing the staging web app to deploy to."
  type = object({
    s3_bucket = object({ bucket = string, arn = string })
  })
}
