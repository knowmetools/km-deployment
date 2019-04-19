locals {
  appspec_key         = "appspec.yaml"
  deploy_params_key   = "deploy-params.zip"
  task_definition_key = "taskdef.json"
}


################################################################################
#                              Deployment Pipeline                             #
################################################################################

resource "aws_codepipeline" "build_pipeline" {
  name     = "${var.app_slug}-build-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category         = "Source"
      name             = "APISource"
      output_artifacts = ["APISource"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"

      configuration = {
        Branch               = var.api_source_branch
        Owner                = var.source_owner
        PollForSourceChanges = "false"
        Repo                 = var.api_source_repo
      }
    }

    action {
      category         = "Source"
      name             = "WebAppSource"
      output_artifacts = ["WebAppSource"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"

      configuration = {
        Branch               = var.web_app_source_branch
        Owner                = var.source_owner
        PollForSourceChanges = "false"
        Repo                 = var.web_app_source_repo
      }
    }

    action {
      category         = "Source"
      name             = "DeployParams"
      output_artifacts = ["DeployParams"]
      owner            = "AWS"
      provider         = "S3"
      version          = "1"

      configuration = {
        PollForSourceChanges = "true"
        S3Bucket             = aws_s3_bucket.api_deploy_params.bucket
        S3ObjectKey          = local.deploy_params_key
      }
    }
  }

  stage {
    name = "Build"

    action {
      category         = "Build"
      input_artifacts  = ["APISource"]
      name             = "APIBuild"
      output_artifacts = ["ImageDefinitions"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration = {
        ProjectName = module.api_codebuild.project_name
      }
    }

    action {
      category         = "Build"
      input_artifacts  = ["WebAppSource"]
      name             = "WebAppBuild"
      output_artifacts = ["WebAppBuild"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration = {
        ProjectName = module.web_app_codebuild.project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category        = "Deploy"
      input_artifacts = ["DeployParams", "ImageDefinitions"]
      name            = "APIDeploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"

      configuration = {
        ApplicationName                = aws_codedeploy_app.api.name
        AppSpecTemplateArtifact        = "DeployParams"
        AppSpecTemplatePath            = local.appspec_key
        DeploymentGroupName            = aws_codedeploy_deployment_group.main.deployment_group_name
        Image1ArtifactName             = "ImageDefinitions"
        Image1ContainerName            = var.api_task_definition_image_placeholder
        TaskDefinitionTemplateArtifact = "DeployParams"
      }
    }

    action {
      category        = "Deploy"
      input_artifacts = ["WebAppBuild"]
      name            = "WebAppDeploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"

      configuration = {
        BucketName = var.web_app_bucket.bucket
        Extract    = "true"
      }
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               GitHub Webhooks                              //
////////////////////////////////////////////////////////////////////////////////

module "api_pipeline_source_hook" {
  source = "./codepipeline-github-webhook"

  github_repository = var.api_source_repo
  app_slug          = "${var.app_slug}-api"
  source_branch     = var.api_source_branch
  target_action     = "APISource"
  target_pipeline   = aws_codepipeline.build_pipeline.name
}

module "web_app_pipeline_source_hook" {
  source = "./codepipeline-github-webhook"

  github_repository = var.web_app_source_repo
  app_slug          = "${var.app_slug}-web-app"
  source_branch     = var.web_app_source_branch
  target_action     = "WebAppSource"
  target_pipeline   = aws_codepipeline.build_pipeline.name
}

################################################################################
#                                   CodeBuild                                  #
################################################################################

module "api_codebuild" {
  source = "./codebuild-project"

  artifact_s3_arn    = aws_s3_bucket.codepipeline_artifacts.arn
  description        = "Build the Docker image for the ${var.app_name} API."
  image              = "aws/codebuild/docker:18.09.0"
  log_retention_days = var.log_retention_days
  name               = "${var.app_slug}-api-docker-build"
  privileged_mode    = true

  environment_variables = {
    ECR_URI      = var.api_ecr_repository.repository_url
    SERVICE_NAME = var.api_service_name
  }
}

module "web_app_codebuild" {
  source = "./codebuild-project"

  artifact_s3_arn = aws_s3_bucket.codepipeline_artifacts.arn
  description     = "Build the ${var.app_slug} Web Application"
  image           = "aws/codebuild/nodejs:10.14.1"
  name            = "${var.app_slug}-web-app-build"
  tags            = var.base_tags

  environment_variables = {
    REACT_APP_API_ROOT = var.api_url
  }
}

################################################################################
#                                  CodeDeploy                                  #
################################################################################

resource "aws_codedeploy_app" "api" {
  compute_platform = "ECS"
  name             = "${var.app_slug}-api"
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.api.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "api-web-servers"
  service_role_arn       = aws_iam_role.api_deploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.api_ecs_cluster
    service_name = var.api_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.api_lb_listener.arn]
      }

      target_group {
        name = var.api_lb_target_group_1.name
      }

      target_group {
        name = var.api_lb_target_group_2.name
      }
    }
  }
}

################################################################################
#                                  S3 Buckets                                  #
################################################################################

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "${var.app_slug}-codepipeline-artifacts"
  force_destroy = true
  tags          = merge(var.base_tags, { Name = "${var.app_name} CodePipeline Artifacts" })
}

////////////////////////////////////////////////////////////////////////////////
//                          API Deployment Parameters                         //
////////////////////////////////////////////////////////////////////////////////

resource "aws_s3_bucket" "api_deploy_params" {
  bucket        = "${var.app_slug}-api-deploy-params"
  force_destroy = true
  tags          = merge(var.base_tags, { Name = "${var.app_name} API Deployment Parameters" })

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_object" "api_deploy_params" {
  bucket = aws_s3_bucket.api_deploy_params.bucket
  etag   = data.archive_file.api_deploy_params.output_md5
  key    = local.deploy_params_key
  source = data.archive_file.api_deploy_params.output_path
}

data "archive_file" "api_deploy_params" {
  output_path = "${path.module}/files/api-deploy-params.zip"
  type        = "zip"

  source {
    content  = data.template_file.appspec.rendered
    filename = local.appspec_key
  }

  source {
    content  = var.api_task_definition_file.rendered
    filename = local.task_definition_key
  }
}

data "template_file" "appspec" {
  template = file("${path.module}/templates/appspec.yml")

  vars = {
    before_install_hook = module.migrate_hook.function_name
    container_name      = var.api_web_container_name
    container_port      = var.api_web_container_port
  }
}

################################################################################
#                      Database Migrations Lambda Function                     #
################################################################################

module "migrate_hook" {
  source = "../lambda"

  function_name       = "${var.app_slug}-api-migration-hook"
  handler             = "lambda_handler.handler"
  log_retention_days  = var.log_retention_days
  runtime             = "python3.7"
  source_archive      = data.archive_file.migrate_lambda_source.output_path
  source_archive_hash = data.archive_file.migrate_lambda_source.output_base64sha256
  timeout             = 120

  environment_variables = {
    ADMIN_EMAIL                      = var.admin_email
    ADMIN_PASSWORD_SSM_NAME          = var.admin_password_ssm_param.name
    CLUSTER                          = var.api_ecs_cluster
    CONTAINER_NAME                   = var.api_web_container_name
    DATABASE_ADMIN_PASSWORD_SSM_NAME = var.database_admin_password_ssm_param.name
    DATABASE_ADMIN_USER              = var.database_admin_user
    SECURITY_GROUPS                  = join(",", var.api_migration_security_group_ids)
    SUBNETS                          = join(",", var.api_migration_subnet_ids)
  }
}

////////////////////////////////////////////////////////////////////////////////
//                             Lambda Source Files                            //
////////////////////////////////////////////////////////////////////////////////

data "archive_file" "migrate_lambda_source" {
  output_path = "${path.module}/files/migrate-lambda-source.zip"
  type        = "zip"

  source {
    content = file(
      "${path.module}/../../scripts/api-lambda-tasks/migration_handler.py",
    )
    filename = "lambda_handler.py"
  }

  source {
    content  = file("${path.module}/../../scripts/api-lambda-tasks/utils.py")
    filename = "utils.py"
  }
}

################################################################################
#                            Deployment Permissions                            #
################################################################################

////////////////////////////////////////////////////////////////////////////////
//                                CodePipeline                                //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role" "codepipeline" {
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
  name               = "${var.app_slug}-codepipeline"
}

data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["codepipeline.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
  policy_arn = aws_iam_policy.codepipeline_policy.arn
  role       = aws_iam_role.codepipeline.name
}

resource "aws_iam_policy" "codepipeline_policy" {
  name   = "${var.app_slug}-code-pipeline-artifacts"
  policy = data.aws_iam_policy_document.codepipeline_policy.json

}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.codepipeline_artifacts.arn,
      "${aws_s3_bucket.codepipeline_artifacts.arn}/*",
      aws_s3_bucket.api_deploy_params.arn,
      "${aws_s3_bucket.api_deploy_params.arn}/*",
      var.web_app_bucket.arn,
      "${var.web_app_bucket.arn}/*",
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:ListApplications",
      "codedeploy:ListDeploymentGroups",
      "codedeploy:RegisterApplicationRevision",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "iam:ListRoles",
      "iam:PassRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_deploy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codepipeline.name
}

////////////////////////////////////////////////////////////////////////////////
//                                  CodeBuild                                 //
////////////////////////////////////////////////////////////////////////////////

# TODO: Limit permissions here
resource "aws_iam_role_policy_attachment" "codebuild_ecs" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = module.api_codebuild.service_role
}

resource "aws_iam_role_policy_attachment" "web_app_codebuild_artifact_access" {
  policy_arn = aws_iam_policy.codebuild_artifact_access.arn
  role       = module.web_app_codebuild.service_role
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
    resources = ["${aws_s3_bucket.codepipeline_artifacts.arn}/*"]
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 CodeDeploy                                 //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role" "api_deploy" {
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role_policy.json
  name               = "${var.app_slug}-codedeploy"
}

data "aws_iam_policy_document" "codedeploy_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["codedeploy.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.api_deploy.name
}

////////////////////////////////////////////////////////////////////////////////
//                              Migration Lambda                              //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role_policy_attachment" "migration_lambda" {
  policy_arn = aws_iam_policy.migration_lambda.arn
  role       = module.migrate_hook.iam_role
}

resource "aws_iam_policy" "migration_lambda" {
  name   = "${var.app_slug}-api-migration-lambda"
  policy = data.aws_iam_policy_document.migration_lambda.json
}

data "aws_iam_policy_document" "migration_lambda" {
  statement {
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
  statement {
    actions = [
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "ecs:RunTask",
    ]
    resources = [
      "arn:aws:codedeploy:*:*:application:${aws_codedeploy_app.api.name}",
      "arn:aws:codedeploy:*:*:deploymentgroup:${aws_codedeploy_app.api.name}/*",
      "arn:aws:ecs:*:*:task-definition/${var.api_task_definition.family}:*",
    ]
  }

  statement {
    actions = [
      "codedeploy:PutLifecycleEventHookExecutionStatus",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:*:*:parameter${var.admin_password_ssm_param.name}",
      "arn:aws:ssm:*:*:parameter${var.database_admin_password_ssm_param.name}",
    ]
  }
}
