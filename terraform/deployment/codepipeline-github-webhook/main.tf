resource "aws_codepipeline_webhook" "this" {
  authentication  = "GITHUB_HMAC"
  name            = "${var.app_slug}-hook"
  target_action   = var.target_action
  target_pipeline = var.target_pipeline

  authentication_configuration {
    secret_token = random_string.webhook_secret.result
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.source_branch}"
  }
}

resource "github_repository_webhook" "this" {
  events     = var.github_events
  repository = var.github_repository

  configuration {
    content_type = "json"
    insecure_ssl = false
    secret       = random_string.webhook_secret.result
    url          = aws_codepipeline_webhook.this.url
  }
}

resource "random_string" "webhook_secret" {
  length = var.webhook_secret_length
}
