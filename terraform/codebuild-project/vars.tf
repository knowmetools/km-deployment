variable "artifact_s3_arn" {
  description = "The ARN of the S3 bucket used to store artifacts for the project."
}

variable "artifact_type" {
  default     = "CODEPIPELINE"
  description = "The type of artifact output by the CodeBuild project."
}

variable "build_timeout" {
  default     = 5
  description = "The number of minutes after which the build will timeout."
}

variable "compute_type" {
  default     = "BUILD_GENERAL1_SMALL"
  description = "The instance type to use for the build process."
}

variable "description" {
  default     = ""
  description = "A description of the CodeBuild project's purpose."
}

variable "environment_type" {
  default     = "LINUX_CONTAINER"
  description = "The type of environment the project runs on (i.e. Linux or Windows)."
}

variable "environment_variables" {
  default     = {}
  description = "A list of name-value pairs describing the environment variables accessible to the build process."
  type        = map(string)
}

variable "image" {
  description = "The name of the Docker image to run the project on."
}

variable "name" {
  description = "The name of the CodeBuild project."
}

variable "privileged_mode" {
  default     = false
  description = "A boolean indicating if the build should run in privileged mode (sudo enabled)."
}

variable "source_type" {
  default     = "CODEPIPELINE"
  description = "The type of source artifact that the build receives."
}

variable "tags" {
  default = {
  }
  description = "A map of tags to apply to the CodeBuild project."
  type        = map(string)
}

