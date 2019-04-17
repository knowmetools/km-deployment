variable "environment_variables" {
  default = {
  }
  description = "A map of environment variables to execute the function with."
  type        = map(string)
}

variable "function_name" {
  description = "The name of the lambda function to create."
}

variable "handler" {
  description = "The name of the handler within the source archive that is the entry point into the function."
}

variable "log_retention_days" {
  default     = 30
  description = "The number of days to keep logs for the Lambda function."
}

variable "runtime" {
  description = "The name of the lambda runtime to execute the function with."
}

variable "source_archive" {
  description = "The path to the source archive to use as the source of the lambda function."
}

variable "source_archive_hash" {
  description = "The base 64 encoded SHA 256 hash of the source archive."
}

variable "timeout" {
  description = "The number of seconds before the function times out."
}

