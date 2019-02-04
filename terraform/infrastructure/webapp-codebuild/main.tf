data "aws_s3_bucket" "deploy" {
  bucket = "${var.deploy_bucket}"
}

data "github_repository" "webapp" {
  name = "${var.source_repository}"
}

################################################################################
#                             Web App CodePipeline                             #
################################################################################

resource "aws_codepipeline" "webapp" {
  name     = "${var.app_slug}-web-app-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.artifacts.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category         = "Source"
      name             = "Source"
      output_artifacts = ["source"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"

      configuration = {
        Branch = "${var.source_branch}"
        Owner  = "knowmetools"
        Repo   = "${data.github_repository.webapp.name}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      category         = "Build"
      input_artifacts  = ["source"]
      name             = "Build"
      output_artifacts = ["build"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.webapp.name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category        = "Deploy"
      input_artifacts = ["build"]
      name            = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"

      configuration {
        BucketName = "${var.deploy_bucket}"
        Extract    = "true"
      }
    }
  }
}

resource "aws_codepipeline_webhook" "bar" {
  name            = "${var.app_slug}-web-app-hook"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = "${aws_codepipeline.webapp.name}"

  authentication_configuration {
    secret_token = "${random_string.webhook_secret.result}"
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.source_branch}"
  }
}

resource "github_repository_webhook" "bar" {
  repository = "${data.github_repository.webapp.name}"
  name       = "web"

  configuration {
    url          = "${aws_codepipeline_webhook.bar.url}"
    content_type = "json"
    insecure_ssl = true
    secret       = "${random_string.webhook_secret.result}"
  }

  events = ["push"]
}

################################################################################
#                               CodeBuild Project                              #
################################################################################

resource "aws_codebuild_project" "webapp" {
  build_timeout = 5
  description   = "Automatically deploy changes to the ${var.app_slug} web application."
  name          = "${var.app_slug}-webapp"
  service_role  = "${aws_iam_role.codebuild.arn}"
  tags          = "${var.base_tags}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:10.14.1"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "REACT_APP_API_ROOT"
      value = "${var.api_root}"
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}

################################################################################
#                              Artifact S3 Bucket                              #
################################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.app_slug}-web-artifacts"
  force_destroy = true

  tags = "${merge(
    var.base_tags,
    map("Name", "${var.app_slug} Web App Artifacts")
  )}"
}

################################################################################
#                           IAM Role for CodePipeline                          #
################################################################################

resource "aws_iam_role" "codepipeline" {
  name = "${var.app_slug}-web-app-code-pipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.app_slug}-web-app-code-pipeline-artifacts"
  role = "${aws_iam_role.codepipeline.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.artifacts.arn}",
        "${aws_s3_bucket.artifacts.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${data.aws_s3_bucket.deploy.arn}",
        "${data.aws_s3_bucket.deploy.arn}/*"
      ]
    }
  ]
}
EOF
}

################################################################################
#                            IAM Role for CodeBuild                            #
################################################################################

resource "aws_iam_role" "codebuild" {
  name = "${var.app_slug}-codebuild-webapp"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_artifacts" {
  role = "${aws_iam_role.codebuild.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.artifacts.arn}",
        "${aws_s3_bucket.artifacts.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_log" {
  role = "${aws_iam_role.codebuild.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    }
  ]
}
POLICY
}

################################################################################
#                                    Secrets                                   #
################################################################################

resource "random_string" "webhook_secret" {
  length = 32
}
