variable "admin_email" {
  description = "The email address of the application admin user."
}

variable "api_ecr_repository" {
  description = "The ECR repository containing the Docker images for the API."
  type        = object({ repository_url = string })
}

variable "api_ecs_cluster" {
  description = "The name of the ECS cluster running the API."
}

variable "api_lb_listener" {
  description = "The listener for the API load balancer that routes traffic to the API."
  type        = object({ arn = string })
}

variable "api_lb_target_group_1" {
  description = "The first load balancer target group for the API."
  type        = object({ name = string })
}

variable "api_lb_target_group_2" {
  description = "The second load balancer target group for the API."
  type        = object({ name = string })
}

variable "api_migration_security_group_ids" {
  description = "A list of IDs of the security groups that the database migration task is placed in."
  type        = list(string)
}

variable "api_migration_subnet_ids" {
  description = "A list of IDs of the subnets that the database migration task can be run in."
  type        = list(string)
}

variable "api_service_name" {
  description = "The name of the ECS service running the API."
}

variable "api_source_branch" {
  description = "The branch of the API source repository to build."
}

variable "api_source_repo" {
  description = "The name of the API source repository."
}

variable "api_task_definition" {
  description = "The task definition used by the API web servers."
  type        = object({ family = string })
}

variable "api_task_definition_file" {
  description = "The template file containing the contents of the API's task definition."
  type        = object({ rendered = string })
}

variable "api_task_definition_image_placeholder" {
  description = "The placeholder value in the API task definition that is replaced with a Docker image version."
}

variable "api_url" {
  description = "The URL of the root of the API."
}

variable "api_web_container_name" {
  description = "The name of the container in the API ECS service running the API."
}

variable "api_web_container_port" {
  description = "The port that the API containers expose."
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

variable "database_admin_password_ssm_param" {
  description = "The SSM parameter storing the password of the admin user on the database that the migration task is run against."
  type        = object({ name = string })
}

variable "database_admin_user" {
  description = "The name of the admin user on the database that the migration task is run against."
}

variable "database_password_ssm_param" {
  description = "The SSM parameter storing the database password."
  type        = object({ name = string })
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

variable "web_app_bucket" {
  description = "The S3 bucket that the compiled web app is stored in."
  type        = object({ arn = string, bucket = string })
}

variable "web_app_source_branch" {
  description = "The branch of the web app repository to build."
}

variable "web_app_source_repo" {
  description = "The name of the web app source repository."
}
