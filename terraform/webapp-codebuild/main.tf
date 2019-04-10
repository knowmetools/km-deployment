data "aws_s3_bucket" "deploy" {
  bucket = var.deploy_bucket
}

data "github_repository" "webapp" {
  name = var.source_repository
}

################################################################################
#                             Web App CodePipeline                             #
################################################################################

resource "aws_codepipeline" "webapp" {
  name     = "${var.app_slug}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = var.codepipeline_artifact_bucket.bucket
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
        Branch               = var.source_branch
        Owner                = "knowmetools"
        PollForSourceChanges = "false"
        Repo                 = data.github_repository.webapp.name
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
        ProjectName = module.webapp_codebuild.project_name
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

      configuration = {
        BucketName = var.deploy_bucket
        Extract    = "true"
      }
    }
  }
}

module "pipeline_source_hook" {
  source = "../codepipeline-github-webhook"

  github_repository = data.github_repository.webapp.name
  app_slug          = var.app_slug
  source_branch     = var.source_branch
  target_action     = "Source"
  target_pipeline   = aws_codepipeline.webapp.name
}

################################################################################
#                               CodeBuild Project                              #
################################################################################

module "webapp_codebuild" {
  source = "../codebuild-project"

  artifact_s3_arn = var.codepipeline_artifact_bucket.arn
  description     = "Build ${var.app_slug}"
  image           = "aws/codebuild/nodejs:10.14.1"
  name            = "${var.app_slug}-build"
  tags            = var.base_tags

  environment_variables = {
    REACT_APP_API_ROOT = var.api_root
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_artifact_access" {
  policy_arn = aws_iam_policy.codebuild_artifact_access.arn
  role       = module.webapp_codebuild.service_role
}

resource "aws_iam_policy" "codebuild_artifact_access" {
  name   = "${var.app_slug}-codebuild-artifact-access"
  policy = data.aws_iam_policy_document.codebuild_artifact_access.json
}

data "aws_iam_policy_document" "codebuild_artifact_access" {
  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = ["${var.codepipeline_artifact_bucket.arn}/*"]
  }
}

################################################################################
#                           IAM Role for CodePipeline                          #
################################################################################

resource "aws_iam_role" "codepipeline" {
  name = "${var.app_slug}-code-pipeline"

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
  name = "${var.app_slug}-code-pipeline-artifacts"
  role = aws_iam_role.codepipeline.id

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
        "${var.codepipeline_artifact_bucket.arn}",
        "${var.codepipeline_artifact_bucket.arn}/*"
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

