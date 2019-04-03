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

variable "runtime" {
  description = "The name of the lambda runtime to execute the function with."
}

variable "source_archive" {
  description = "The path to the source archive to use as the source of the lambda function."
}

variable "timeout" {
  description = "The number of seconds before the function times out."
}

