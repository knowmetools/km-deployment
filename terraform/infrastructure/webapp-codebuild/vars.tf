variable "api_root" {
  description = "The root of the API that the webapp interacts with."
}

variable "app_slug" {
  description = "A unique slug identifying the application."
}

variable "base_tags" {
  default     = {}
  description = "A base set of tags to apply to all taggable resources in the module."
  type        = "map"
}

variable "s3_arn" {
  description = "The ARN of the S3 bucket that the webapp is uploaded to."
}

variable "s3_bucket" {
  description = "The name of the S3 bucket that the webapp is uploaded to."
}

variable "source_branch" {
  default     = "master"
  description = "The name of the branch to listen to changes on."
}
