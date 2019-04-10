variable "app_slug" {
  description = "A unique slug identifying the application."
}

variable "github_events" {
  default     = ["push"]
  description = "A list containing the events to watch for on the source repository."
  type        = list(string)
}

variable "github_repository" {
  description = <<EOF
The name of the GitHub repository to watch for changes. This repository must be
owned by the owner configured for the GitHub provider.
EOF
}

variable "source_branch" {
  description = "The branch of the GitHub repository to monitor for changes."
}

variable "target_action" {
  description = "The name of the CodePipeline action to trigger."
}

variable "target_pipeline" {
  description = "The name of the CodePipeline to trigger."
}

variable "webhook_secret_length" {
  default = 32
  description = "The length of the secret to use for the webhook."
}
