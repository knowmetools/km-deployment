locals {
  api_web_container_port = 8000
  api_web_container_name = "api-web-server"
  image_placeholder      = "IMAGE"
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

data "template_file" "container_definitions" {
  template = file("${path.module}/templates/container-definitions.json")

  vars = {
    aws_region        = var.aws_region
    container_name    = local.api_web_container_name
    container_port    = local.api_web_container_port
    environment       = jsonencode(var.api_environment)
    image_placeholder = local.image_placeholder
    log_group         = aws_cloudwatch_log_group.api.name
    secrets           = jsonencode(var.api_secrets)
  }
}

data "template_file" "task_definition" {
  template = file("${path.module}/templates/taskdef.json")

  vars = {
    container_definitions = data.template_file.container_definitions.rendered
    execution_role_arn    = aws_iam_role.api_task_execution_role.arn
    task_role_arn         = aws_iam_role.api_task_role.arn
  }
}

data "archive_file" "background_lambda_source" {
  output_path = "${path.module}/files/background-lambda-source.zip"
  type        = "zip"

  source {
    content  = file("${path.module}/../../../scripts/api-lambda-tasks/background_handler.py")
    filename = "lambda_handler.py"
  }

  source {
    content  = file("${path.module}/../../../scripts/api-lambda-tasks/utils.py")
    filename = "utils.py"
  }
}

module "background_jobs_lambda" {
  source = "../../lambda"

  function_name       = "${var.app_slug}-invoke-background-jobs"
  handler             = "lambda_handler.handler"
  log_retention_days  = var.log_retention_days_api
  runtime             = "python3.7"
  source_archive      = data.archive_file.background_lambda_source.output_path
  source_archive_hash = data.archive_file.background_lambda_source.output_base64sha256
  timeout             = 60

  environment_variables = {
    CLUSTER         = aws_ecs_cluster.main.name
    CONTAINER_NAME  = local.api_web_container_name
    SECURITY_GROUPS = aws_security_group.api.id
    SERVICE         = aws_ecs_service.api.name
    SUBNETS         = join(",", var.subnet_ids)
  }
}

resource "aws_cloudwatch_event_rule" "background_trigger" {
  name                = "${var.app_slug}-background-jobs-trigger"
  description         = "Trigger background jobs for ${var.app_slug} periodically."
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "background_jobs_lambda" {
  arn       = module.background_jobs_lambda.function_arn
  rule      = aws_cloudwatch_event_rule.background_trigger.name
  target_id = "${var.app_slug}-background-jobs-lambda-function"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "${var.app_slug}-background-task-cloudwatch-invokation"
  action        = "lambda:InvokeFunction"
  function_name = module.background_jobs_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.background_trigger.arn
}

resource "aws_ecs_cluster" "main" {
  name = var.app_slug
}

resource "aws_ecr_repository" "api" {
  name = var.app_slug
}

resource "aws_ecs_service" "api" {
  depends_on = [aws_lb_listener.api]

  cluster                            = aws_ecs_cluster.main.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  launch_type                        = "FARGATE"
  name                               = "api"
  task_definition                    = aws_ecs_task_definition.api.arn

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name   = local.api_web_container_name
    container_port   = local.api_web_container_port
    target_group_arn = aws_lb_target_group.green.arn
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.api.id]
    subnets          = var.subnet_ids
  }

  lifecycle {
    # Ignore changes to the task definition since deployments will have
    # overwritten this value to a newer task definition.
    ignore_changes = [
      load_balancer,
      task_definition,
    ]
  }
}

resource "aws_ecs_task_definition" "api" {
  # This task definition is never actually used, but we need to replace
  # the placeholder used by CodeDeploy with a set of valid characters so
  # we can create the initial task definition.
  container_definitions = replace(
    data.template_file.container_definitions.rendered,
    "<${local.image_placeholder}>",
    "dummy-image",
  )

  cpu                      = 256
  execution_role_arn       = aws_iam_role.api_task_execution_role.arn
  family                   = "api"
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  lifecycle {
    # We don't actually care about updating the container definitions
    # because that is handled by CodeDeploy and updated outside of
    # Terraform.
    ignore_changes = [container_definitions]
  }
}

resource "aws_lb" "api" {
  name            = "${var.app_slug}-lb"
  security_groups = [aws_security_group.lb.id]
  subnets         = var.subnet_ids
}

resource "aws_lb_listener" "redirect_to_https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "api" {
  certificate_arn   = var.certificate_arn
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = aws_lb_target_group.green.arn
    type             = "forward"
  }

  lifecycle {
    # The target group is constantly switched back and forth by
    # deployments.
    ignore_changes = [default_action]
  }
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.app_slug}-blue"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 5
    matcher             = "200"
    path                = "/status/"
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.app_slug}-green"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 5
    matcher             = "200"
    path                = "/status/"
    unhealthy_threshold = 3
  }
}

resource "aws_security_group" "api" {
  name   = "${var.app_slug}-web-servers"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "api_in" {
  description              = "Allow incoming connections from the load balancer."
  from_port                = local.api_web_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.api.id
  source_security_group_id = aws_security_group.lb.id
  to_port                  = local.api_web_container_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "api_out_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outgoing HTTP connections."
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.api.id
  to_port           = 80
  type              = "egress"
}

resource "aws_security_group_rule" "api_out_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outgoing HTTPS connections."
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.api.id
  to_port           = 443
  type              = "egress"
}

resource "aws_security_group" "lb" {
  name   = "${var.app_slug}-load-balancer"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "lb_in_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow incoming HTTP connections."
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  to_port           = 80
  type              = "ingress"
}

resource "aws_security_group_rule" "lb_in_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow incoming HTTPS connections."
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group_rule" "lb_out_api" {
  description              = "Allow outgoing traffic from the load balancer to the web servers."
  from_port                = local.api_web_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lb.id
  source_security_group_id = aws_security_group.api.id
  to_port                  = local.api_web_container_port
  type                     = "egress"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = var.app_slug
  retention_in_days = var.log_retention_days_api
}

resource "aws_iam_role" "api_task_execution_role" {
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  // TODO: Figure out why the following line crashes Terraform
  //  name               = "${var.app_slug}-ecs-execution"
  name = "${var.app_slug}-ecs-task-execution"
}

resource "aws_iam_role_policy_attachment" "AWSECSRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.api_task_execution_role.name
}

resource "aws_iam_role_policy_attachment" "task_ssm_access" {
  policy_arn = aws_iam_policy.task_ssm_access.arn
  role       = aws_iam_role.api_task_execution_role.name
}

resource "aws_iam_policy" "task_ssm_access" {
  name = "${var.app_slug}-ecs-execution-ssm-access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "api_task_role" {
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  name = "${var.app_slug}-ecs-task"
}

################################################################################
#                              Lambda Permissions                              #
################################################################################

resource "aws_iam_role_policy_attachment" "background_lambda" {
  policy_arn = aws_iam_policy.background_lambda.arn
  role = module.background_jobs_lambda.iam_role
}

resource "aws_iam_policy" "background_lambda" {
  name = "${var.app_slug}-lambda-background-jobs"
  policy = data.aws_iam_policy_document.background_lambda.json
}

data "aws_iam_policy_document" "background_lambda" {
  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "iam:PassRole",
    ]
    resources = ["*"]
  }

  statement {
    actions = ["ecs:RunTask"]
    resources = [
      "arn:aws:ecs:*:*:task-definition/${aws_ecs_task_definition.api.family}:*"
    ]
  }
}
