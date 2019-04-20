variable "admin_email" {
  description = "The email address of the application's admin user."
}

variable "app_slug" {
  description = "A slugified version of the application's name."
}

variable "appspec_key" {
  description = "The location inside the deployment parameters archive file that the Appspec file is stored."
}

variable "container_name" {
  description = "The name of the container definition being deployed to."
}

variable "container_port" {
  description = "The port over which the service is accessed."
}

variable "database_admin_password_ssm_param" {
  description = "The SSM parameter containing the password of the admin user for the database."
  type        = object({ arn = string, name = string })
}

variable "database_admin_user" {
  description = "The name of the admin user for the database."
}

variable "deploy_params_s3_bucket" {
  description = "The name of the S3 bucket to store the ECS deployment parameters in."
}

variable "deploy_params_key" {
  description = "The key inside the deployment parameters S3 bucket under which the parameters are stored."
}

variable "ecs_cluster" {
  description = "The name of the ECS cluster running the ECS service to deploy to."
}

variable "ecs_service" {
  description = "The name of the ECS service to deploy to."
}

variable "lb_listener_arn" {
  description = "The ARN of the load balancer listener that directs traffic to the service being deployed to."
}

variable "lb_target_group_1" {
  description = "The name of the first target group for the service's load balancer."
}

variable "lb_target_group_2" {
  description = "The name of the second target group for the service's load balancer."
}

variable "log_retention_days" {
  description = "The number of days to retain logs related to the deployment process."
}

variable "migration_security_group_ids" {
  description = "A list of IDs for the security groups that the database migration task is run in."
  type        = list(string)
}

variable "migration_subnet_ids" {
  description = "A list of IDs of the subnets that the database migration task could be run in."
  type        = list(string)
}

variable "ssm_parameter_prefix" {
  description = "A prefix for all SSM parameters created in the module."
}

variable "task_definition_content" {
  description = "The content of the task definition used for the deployment."
}

variable "task_definition_family" {
  description = "The task definition family used by the service being deployed."
}

variable "task_definition_key" {
  description = "The location inside the deployment parameters archive file where the task definition is stored."
}
