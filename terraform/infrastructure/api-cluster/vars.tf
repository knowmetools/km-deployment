variable "api_environment" {
  default     = []
  description = "A list of key-value pairs to provide to the API service as environment variables."
  type        = list(object({ name = string, value = string }))
}

variable "api_secrets" {
  default     = []
  description = "A list of key-value pairs of secrets to provide to the API service as environment variables."
  type        = list(object({ name = string, valueFrom = string }))
}

variable "app_slug" {
  description = "A unique slug identifying the application."
}

variable "aws_region" {
  description = "The AWS region to provision resources in."
}

variable "certificate_arn" {
  description = "The ARN of the certificate used for HTTPS connections to the API."
}

variable "codepipeline_artifact_bucket" {
  description = "The S3 bucket used to store CodePipeline artifacts."
  type        = object({ arn = string, bucket = string })
}

variable "django_admin_email" {
}

variable "django_admin_password_ssm_name" {
  description = "The name of the SSM parameter containing the admin user to create during deployments."
}

variable "source_branch" {
  default     = "master"
  description = "The branch of the source GitHub repository to deploy."
}

variable "source_owner" {
  description = "The owner (user/organization) of the source repository for the API."
}

variable "source_repo" {
  description = "The name of the GitHub repository containing the source code for the API."
}

variable "subnet_ids" {
  description = "A list of the subnets to create cluster resources in."
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC to create the cluster in."
}

