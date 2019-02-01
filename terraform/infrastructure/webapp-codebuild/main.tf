data "aws_region" "current" {}

################################################################################
#                               CodeBuild Project                              #
################################################################################

resource "aws_codebuild_project" "webapp" {
  build_timeout = 5
  description   = "Automatically deploy changes to the ${var.app_slug} web application."
  name          = "${var.app_slug}-webapp"
  service_role  = "${aws_iam_role.codebuild.name}"
  tags          = "${var.base_tags}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:10.14.1"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "REACT_APP_API_ROOT"
      value = "${var.api_root}"
    }

    environment_variable {
      name  = "S3_BUCKET"
      value = "${var.s3_bucket}"
    }
  }

  source {
    git_clone_depth = 1
    location        = "https://github.com/knowmetools/km-web.git"
    type            = "GITHUB"
  }
}

# Webhook to run CodeBuild when the source code changes
resource "aws_codebuild_webhook" "webapp" {
  branch_filter = "${var.source_branch}"
  project_name  = "${aws_codebuild_project.webapp.name}"
}

# If we just created the CodeBuild project, trigger an initial run so
# that we don't have to push a change to the webapp for it to be
# deployed for the first time.
resource "null_resource" "initial_codebuild" {
  provisioner "local-exec" {
    command = "aws codebuild start-build --project-name ${aws_codebuild_project.webapp.name} --region ${data.aws_region.current.name} --source-version ${var.source_branch}"
  }

  triggers {
    project_name = "${aws_codebuild_project.webapp.name}"
  }
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

resource "aws_iam_role_policy" "codebuild-log" {
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

resource "aws_iam_role_policy" "codebuild-deploy" {
  role = "${aws_iam_role.codebuild.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${var.s3_arn}",
        "${var.s3_arn}/*"
      ]
    }
  ]
}
POLICY
}
