################################################################################
#                                  CodeDeploy                                  #
################################################################################

resource "aws_codedeploy_app" "api" {
  compute_platform = "ECS"
  name             = "${var.app_slug}"
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.api.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "api-web-servers"
  service_role_arn       = aws_iam_role.deploy.arn

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
    cluster_name = var.ecs_cluster
    service_name = var.ecs_service
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.lb_listener_arn]
      }

      target_group {
        name = var.lb_target_group_1
      }

      target_group {
        name = var.lb_target_group_2
      }
    }
  }
}

################################################################################
#                             Deployment Parameters                            #
################################################################################

resource "aws_s3_bucket_object" "deploy_params" {
  bucket = var.deploy_params_s3_bucket
  etag   = data.archive_file.api_deploy_params.output_md5
  key    = var.deploy_params_key
  source = data.archive_file.api_deploy_params.output_path
}

data "archive_file" "api_deploy_params" {
  output_path = "${path.module}/files/api-deploy-params.zip"
  type        = "zip"

  source {
    content  = data.template_file.appspec.rendered
    filename = var.appspec_key
  }

  source {
    content  = var.task_definition_content
    filename = var.task_definition_key
  }
}

data "template_file" "appspec" {
  template = file("${path.module}/templates/appspec.yml")

  vars = {
    before_install_hook = module.migrate_hook.function_name
    container_name      = var.container_name
    container_port      = var.container_port
  }
}

################################################################################
#                      Database Migrations Lambda Function                     #
################################################################################

module "migrate_hook" {
  source = "../../lambda"

  function_name       = "${var.app_slug}-migration-hook"
  handler             = "lambda_handler.handler"
  log_retention_days  = var.log_retention_days
  runtime             = "python3.7"
  source_archive      = data.archive_file.migrate_lambda_source.output_path
  source_archive_hash = data.archive_file.migrate_lambda_source.output_base64sha256
  timeout             = 120

  environment_variables = {
    ADMIN_EMAIL                      = var.admin_email
    ADMIN_PASSWORD_SSM_NAME          = aws_ssm_parameter.admin_password.name
    CLUSTER                          = var.ecs_cluster
    CONTAINER_NAME                   = var.container_name
    DATABASE_ADMIN_PASSWORD_SSM_NAME = var.database_admin_password_ssm_param.name
    DATABASE_ADMIN_USER              = var.database_admin_user
    SECURITY_GROUPS                  = join(",", var.migration_security_group_ids)
    SUBNETS                          = join(",", var.migration_subnet_ids)
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
      "${path.module}/../../../scripts/api-lambda-tasks/migration_handler.py",
    )
    filename = "lambda_handler.py"
  }

  source {
    content  = file("${path.module}/../../../scripts/api-lambda-tasks/utils.py")
    filename = "utils.py"
  }
}

################################################################################
#                               Secret Generation                              #
################################################################################

resource "random_string" "admin_password" {
  length = 32
}

////////////////////////////////////////////////////////////////////////////////
//                       Store Secrets as SSM Parameters                      //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// For secrets that we need access to after the deployment process, we store  //
// the values as `SecureString` parameters in SSM. This allows us to inject   //
// the parameters into other process such as ECS services without exposing    //
// the plaintext values.                                                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

resource "aws_ssm_parameter" "admin_password" {
  name  = "${var.ssm_parameter_prefix}/admin/password"
  type  = "SecureString"
  value = random_string.admin_password.result
}

################################################################################
#                            Deployment Permissions                            #
################################################################################

////////////////////////////////////////////////////////////////////////////////
//                                 CodeDeploy                                 //
////////////////////////////////////////////////////////////////////////////////

resource "aws_iam_role" "deploy" {
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
  role       = aws_iam_role.deploy.name
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
      "arn:aws:ecs:*:*:task-definition/${var.task_definition_family}:*",
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
      aws_ssm_parameter.admin_password.arn,
      var.database_admin_password_ssm_param.arn,
    ]
  }
}
