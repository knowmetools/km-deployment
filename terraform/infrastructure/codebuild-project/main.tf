locals {
  codebuild_service_role = "${var.name}-service-role"
}

################################################################################
#                               CodeBuild Project                              #
################################################################################

resource "aws_codebuild_project" "this" {
  build_timeout = var.build_timeout
  description   = var.description
  name          = var.name
  service_role  = aws_iam_role.codebuild.arn
  tags          = var.tags

  artifacts {
    type = var.artifact_type
  }

  environment {
    compute_type    = var.compute_type
    image           = var.image
    privileged_mode = var.privileged_mode
    type            = var.environment_type

    dynamic "environment_variable" {
      for_each = var.environment_variables

      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  source {
    type = var.source_type
  }
}

################################################################################
#                            IAM Roles and Policies                            #
################################################################################

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["codebuild.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "codebuild" {
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
  name               = local.codebuild_service_role
}

////////////////////////////////////////////////////////////////////////////////
//                               Artifact Access                              //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role_policy_attachment" "codebuild_artifacts" {
  policy_arn = aws_iam_policy.codebuild_artifacts.arn
  role       = aws_iam_role.codebuild.name
}

resource "aws_iam_policy" "codebuild_artifacts" {
  description = "Grant CodeBuild access to the S3 bucket that artifacts are pulled from and pushed to."
  name        = "${local.codebuild_service_role}-artifact-access"
  policy      = data.aws_iam_policy_document.codebuild_artifacts.json
}

data "aws_iam_policy_document" "codebuild_artifacts" {
  statement {
    actions   = ["s3:GetBucketVersioning"]
    resources = [var.artifact_s3_arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]

    resources = ["${var.artifact_s3_arn}/*"]
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 Log Access                                 //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  policy_arn = aws_iam_policy.codebuild_log.arn
  role       = aws_iam_role.codebuild.name
}

resource "aws_iam_policy" "codebuild_log" {
  description = "Grant CodeBuild access to creating a log group and putting log events in it."
  name        = "${local.codebuild_service_role}-log-access"
  policy      = data.aws_iam_policy_document.codebuild_logs.json
}

data "aws_iam_policy_document" "codebuild_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

