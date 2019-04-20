locals {
  appspec_key               = "appspec.yaml"
  deploy_params_key         = "deploy-params-production.zip"
  deploy_params_key_staging = "deploy-params-staging.zip"
  task_definition_key       = "taskdef.json"
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
      name             = "DeployParamsProduction"
      output_artifacts = ["DeployParamsProduction"]
      owner            = "AWS"
      provider         = "S3"
      version          = "1"

      configuration = {
        PollForSourceChanges = "true"
        S3Bucket             = aws_s3_bucket.api_deploy_params.bucket
        S3ObjectKey          = local.deploy_params_key
      }
    }

    action {
      category         = "Source"
      name             = "DeployParamsStaging"
      output_artifacts = ["DeployParamsStaging"]
      owner            = "AWS"
      provider         = "S3"
      version          = "1"

      configuration = {
        PollForSourceChanges = "true"
        S3Bucket             = aws_s3_bucket.api_deploy_params.bucket
        S3ObjectKey          = local.deploy_params_key_staging
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
      name             = "WebAppBuildStaging"
      output_artifacts = ["WebAppBuildStaging"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration = {
        ProjectName = module.web_app_codebuild_staging.project_name
      }
    }
  }

  stage {
    name = "DeployStaging"

    action {
      category        = "Deploy"
      input_artifacts = ["DeployParamsStaging", "ImageDefinitions"]
      name            = "APIDeployStaging"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"

      configuration = {
        ApplicationName                = module.api_deploy_staging.codedeploy_app_name
        AppSpecTemplateArtifact        = "DeployParamsStaging"
        AppSpecTemplatePath            = local.appspec_key
        DeploymentGroupName            = module.api_deploy_staging.codedeploy_deployment_group_name
        Image1ArtifactName             = "ImageDefinitions"
        Image1ContainerName            = var.api_task_definition_image_placeholder
        TaskDefinitionTemplateArtifact = "DeployParamsStaging"
      }
    }

    action {
      category        = "Deploy"
      input_artifacts = ["WebAppBuildStaging"]
      name            = "WebAppDeployStaging"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"

      configuration = {
        BucketName = var.web_app_staging.s3_bucket.bucket
        Extract    = "true"
      }
    }
  }

  // We have to rebuild the web app since the API URL it interacts with is
  // baked in at build time.
  stage {
    name = "BuildProduction"

    action {
      category         = "Build"
      input_artifacts  = ["WebAppSource"]
      name             = "WebAppBuildProduction"
      output_artifacts = ["WebAppBuildProduction"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration = {
        ProjectName = module.web_app_codebuild_prod.project_name
      }
    }
  }

  stage {
    name = "DeployProduction"

    action {
      category        = "Deploy"
      input_artifacts = ["DeployParamsProduction", "ImageDefinitions"]
      name            = "APIDeployProduction"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"

      configuration = {
        ApplicationName                = module.api_deploy_prod.codedeploy_app_name
        AppSpecTemplateArtifact        = "DeployParamsProduction"
        AppSpecTemplatePath            = local.appspec_key
        DeploymentGroupName            = module.api_deploy_prod.codedeploy_deployment_group_name
        Image1ArtifactName             = "ImageDefinitions"
        Image1ContainerName            = var.api_task_definition_image_placeholder
        TaskDefinitionTemplateArtifact = "DeployParamsProduction"
      }
    }

    action {
      category        = "Deploy"
      input_artifacts = ["WebAppBuildProduction"]
      name            = "WebAppDeployProduction"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"

      configuration = {
        BucketName = var.web_app_prod.s3_bucket.bucket
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
#                                API Deployment                                #
################################################################################

module "api_deploy_prod" {
  source = "./app-deployment"

  admin_email                       = var.admin_email
  app_slug                          = "${var.app_slug}-api"
  appspec_key                       = local.appspec_key
  container_name                    = var.api_prod.web_container_name
  container_port                    = var.api_prod.web_container_port
  database_admin_password_ssm_param = var.api_prod.database_admin_password_ssm_param
  database_admin_user               = var.api_prod.database_admin_user
  deploy_params_s3_bucket           = aws_s3_bucket.api_deploy_params.bucket
  deploy_params_key                 = local.deploy_params_key
  ecs_cluster                       = var.api_prod.ecs_cluster
  ecs_service                       = var.api_prod.ecs_service
  lb_listener_arn                   = var.api_prod.lb_listener_arn
  lb_target_group_1                 = var.api_prod.lb_target_group_1
  lb_target_group_2                 = var.api_prod.lb_target_group_2
  log_retention_days                = var.log_retention_days
  migration_security_group_ids      = var.api_prod.migration_security_group_ids
  migration_subnet_ids              = var.api_prod.migration_subnet_ids
  ssm_parameter_prefix              = "${var.ssm_parameter_prefix}/production"
  task_definition_content           = var.api_prod.task_definition_content
  task_definition_family            = var.api_prod.task_definition_family
  task_definition_key               = local.task_definition_key
}

module "api_deploy_staging" {
  source = "./app-deployment"

  admin_email                       = var.admin_email
  app_slug                          = "${var.app_slug}-staging-api"
  appspec_key                       = local.appspec_key
  container_name                    = var.api_staging.web_container_name
  container_port                    = var.api_staging.web_container_port
  database_admin_password_ssm_param = var.api_staging.database_admin_password_ssm_param
  database_admin_user               = var.api_staging.database_admin_user
  deploy_params_s3_bucket           = aws_s3_bucket.api_deploy_params.bucket
  deploy_params_key                 = local.deploy_params_key_staging
  ecs_cluster                       = var.api_staging.ecs_cluster
  ecs_service                       = var.api_staging.ecs_service
  lb_listener_arn                   = var.api_staging.lb_listener_arn
  lb_target_group_1                 = var.api_staging.lb_target_group_1
  lb_target_group_2                 = var.api_staging.lb_target_group_2
  log_retention_days                = var.log_retention_days
  migration_security_group_ids      = var.api_staging.migration_security_group_ids
  migration_subnet_ids              = var.api_staging.migration_subnet_ids
  ssm_parameter_prefix              = "${var.ssm_parameter_prefix}/staging"
  task_definition_content           = var.api_staging.task_definition_content
  task_definition_family            = var.api_staging.task_definition_family
  task_definition_key               = local.task_definition_key
}

################################################################################
#                                   CodeBuild                                  #
################################################################################

resource "aws_ecr_repository" "api" {
  name = "${var.app_slug}-api"
}

module "api_codebuild" {
  source = "./codebuild-project"

  artifact_s3_arn    = aws_s3_bucket.codepipeline_artifacts.arn
  description        = "Build the Docker image for the ${var.app_name} API."
  image              = "aws/codebuild/docker:18.09.0"
  log_retention_days = var.log_retention_days
  name               = "${var.app_slug}-api-docker-build"
  privileged_mode    = true

  environment_variables = {
    ECR_URI = aws_ecr_repository.api.repository_url
  }
}

module "web_app_codebuild_prod" {
  source = "./codebuild-project"

  artifact_s3_arn = aws_s3_bucket.codepipeline_artifacts.arn
  description     = "Build the ${var.app_slug} Web Application"
  image           = "aws/codebuild/nodejs:10.14.1"
  name            = "${var.app_slug}-web-app-build"
  tags            = var.base_tags

  environment_variables = {
    REACT_APP_API_ROOT = var.api_prod.url
  }
}

module "web_app_codebuild_staging" {
  source = "./codebuild-project"

  artifact_s3_arn = aws_s3_bucket.codepipeline_artifacts.arn
  description     = "Build the ${var.app_slug} (Staging) Web Application"
  image           = "aws/codebuild/nodejs:10.14.1"
  name            = "${var.app_slug}-staging-web-app-build"
  tags            = var.base_tags

  environment_variables = {
    REACT_APP_API_ROOT = var.api_staging.url
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

resource "aws_s3_bucket" "api_deploy_params" {
  bucket        = "${var.app_slug}-api-deploy-params"
  force_destroy = true
  tags          = merge(var.base_tags, { Name = "${var.app_name} API Deployment Parameters" })

  versioning {
    enabled = true
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
      var.web_app_prod.s3_bucket.arn,
      "${var.web_app_prod.s3_bucket.arn}/*",
      var.web_app_staging.s3_bucket.arn,
      "${var.web_app_staging.s3_bucket.arn}/*",
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

resource "aws_iam_role_policy_attachment" "web_app_production_codebuild_artifact_access" {
  policy_arn = aws_iam_policy.codebuild_artifact_access.arn
  role       = module.web_app_codebuild_prod.service_role
}

resource "aws_iam_role_policy_attachment" "web_app_staging_codebuild_artifact_access" {
  policy_arn = aws_iam_policy.codebuild_artifact_access.arn
  role       = module.web_app_codebuild_staging.service_role
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
