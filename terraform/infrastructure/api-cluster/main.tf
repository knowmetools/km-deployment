data "aws_iam_policy_document" "codedeploy_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
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

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_vpc" "default" {
  default = true
}

data "template_file" "appspec" {
  template = "${file("${path.module}/templates/appspec.yml")}"

  vars {
    container_name = "${local.api_web_container_name}"
  }
}

data "template_file" "task_definition" {
  template = <<EOF
[
  {
    "environment": [
      {
        "name": "DJANGO_DEBUG",
        "value": "True"
      }
    ],
    "image": "$${ecr_uri}",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "us-east-1",
        "awslogs-group": "$${app_slug}",
        "awslogs-stream-prefix": "ecs-api-web"
      }
    },
    "memoryReservation": 128,
    "name": "$${container_name}",
    "portMappings": [
      {
        "containerPort": 8000
      }
    ]
  }
]
EOF

  vars {
    app_slug       = "${var.app_slug}"
    container_name = "${local.api_web_container_name}"
    ecr_uri        = "${aws_ecr_repository.api.repository_url}"
  }
}

data "template_file" "task_definition_deploy" {
  template = "${file("${path.module}/templates/taskdef.json")}"

  vars {
    app_slug           = "${var.app_slug}"
    container_name     = "${local.api_web_container_name}"
    execution_role_arn = "${aws_iam_role.api_task_execution_role.arn}"
    image_placeholder  = "${local.image_placeholder}"
  }
}

data "archive_file" "api_deploy_params" {
  output_path = "${path.module}/files/api-deploy-params.zip"
  type        = "zip"

  source {
    content  = "${data.template_file.appspec.rendered}"
    filename = "${local.appspec_key}"
  }

  source {
    content  = "${data.template_file.task_definition_deploy.rendered}"
    filename = "${local.task_definition_key}"
  }
}

locals {
  api_web_container_name = "api-web-server"
  appspec_key            = "appspec.yaml"
  deploy_params_key      = "deploy-params.zip"
  image_placeholder      = "IMAGE"
  task_definition_key    = "taskdef.json"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.app_slug}"
}

resource "aws_ecr_repository" "api" {
  name = "${var.app_slug}"
}

resource "aws_ecs_service" "api" {
  depends_on = ["aws_lb_listener.api"]

  cluster                            = "${aws_ecs_cluster.main.arn}"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  launch_type                        = "FARGATE"
  name                               = "api"
  task_definition                    = "${aws_ecs_task_definition.api.arn}"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    container_name   = "api-web-server"
    container_port   = 8000
    target_group_arn = "${aws_lb_target_group.green.arn}"
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = ["${aws_security_group.all.id}"]
    subnets          = ["${data.aws_subnet_ids.default.ids}"]
  }
}

resource "aws_ecs_task_definition" "api" {
  container_definitions    = "${data.template_file.task_definition.rendered}"
  cpu                      = 256
  execution_role_arn       = "${aws_iam_role.api_task_execution_role.arn}"
  family                   = "api"
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_lb" "api" {
  name            = "${var.app_slug}-lb"
  security_groups = ["${aws_security_group.all.id}"]
  subnets         = ["${data.aws_subnet_ids.default.ids}"]
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = "${aws_lb.api.arn}"
  port              = 80

  default_action {
    target_group_arn = "${aws_lb_target_group.green.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.app_slug}-lb-target-blue"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${data.aws_vpc.default.id}"
}

resource "aws_lb_target_group" "green" {
  name        = "${var.app_slug}-lb-target-green"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${data.aws_vpc.default.id}"
}

resource "aws_security_group" "all" {
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

################################################################################
#                                API Deployment                                #
################################################################################

resource "aws_codepipeline" "api" {
  name     = "${var.app_slug}-webservers"
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
      output_artifacts = ["Source"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"

      configuration {
        Branch = "docker"
        Owner  = "knowmetools"
        Repo   = "km-api"
      }
    }

    action {
      category         = "Source"
      name             = "DeployParams"
      output_artifacts = ["DeployParams"]
      owner            = "AWS"
      provider         = "S3"
      version          = "1"

      configuration {
        PollForSourceChanges = "true"
        S3Bucket             = "${aws_s3_bucket.source_parameters.bucket}"
        S3ObjectKey          = "${local.deploy_params_key}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      category         = "Build"
      input_artifacts  = ["Source"]
      name             = "Build"
      output_artifacts = ["ImageDefinitions"]
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.api.name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category        = "Deploy"
      input_artifacts = ["DeployParams", "ImageDefinitions"]
      name            = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"

      configuration {
        ApplicationName                = "${aws_codedeploy_app.api.name}"
        AppSpecTemplateArtifact        = "DeployParams"
        AppSpecTemplatePath            = "${local.appspec_key}"
        DeploymentGroupName            = "${aws_codedeploy_deployment_group.main.deployment_group_name}"
        Image1ArtifactName             = "ImageDefinitions"
        Image1ContainerName            = "${local.image_placeholder}"
        TaskDefinitionTemplateArtifact = "DeployParams"
      }
    }
  }
}

resource "aws_codebuild_project" "api" {
  build_timeout = 5
  description   = "Build the Docker image for the ${var.app_slug} API."
  name          = "${var.app_slug}"
  service_role  = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:18.09.0"
    privileged_mode = true
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "ECR_URI"
      value = "${aws_ecr_repository.api.repository_url}"
    }

    environment_variable {
      name  = "SERVICE_NAME"
      value = "${local.api_web_container_name}"
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codedeploy_app" "api" {
  compute_platform = "ECS"
  name             = "${var.app_slug}"
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = "${aws_codedeploy_app.api.name}"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "api-web-servers"
  service_role_arn       = "${aws_iam_role.api_deploy.arn}"

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
    cluster_name = "${aws_ecs_cluster.main.name}"
    service_name = "${aws_ecs_service.api.name}"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = ["${aws_lb_listener.api.arn}"]
      }

      target_group {
        name = "${aws_lb_target_group.blue.name}"
      }

      target_group {
        name = "${aws_lb_target_group.green.name}"
      }
    }
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.app_slug}-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket" "source_parameters" {
  bucket        = "${var.app_slug}-parameters"
  force_destroy = true

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_object" "api_deploy_params" {
  bucket = "${aws_s3_bucket.source_parameters.bucket}"
  etag   = "${data.archive_file.api_deploy_params.output_md5}"
  key    = "${local.deploy_params_key}"
  source = "${data.archive_file.api_deploy_params.output_path}"
}

################################################################################
#                            Deployment Permissions                            #
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
        "${aws_s3_bucket.artifacts.arn}/*",
        "${aws_s3_bucket.source_parameters.arn}",
        "${aws_s3_bucket.source_parameters.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_deploy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = "${aws_iam_role.codepipeline.name}"
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_deploy2" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
  role       = "${aws_iam_role.codepipeline.name}"
}

resource "aws_iam_role" "api_task_execution_role" {
  assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_role_policy.json}"
  name               = "${var.app_slug}-ecs-task-execution"
}

resource "aws_iam_role_policy_attachment" "AWSECSRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = "${aws_iam_role.api_task_execution_role.name}"
}

resource "aws_iam_role" "api_deploy" {
  assume_role_policy = "${data.aws_iam_policy_document.codedeploy_assume_role_policy.json}"
  name               = "${var.app_slug}-codedeploy"
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = "${aws_iam_role.api_deploy.name}"
}

resource "aws_iam_role_policy" "api_deploy_s3" {
  role = "${aws_iam_role.api_deploy.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "*",
        "s3:*"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF
}

resource "aws_iam_role" "codebuild" {
  name = "${var.app_slug}-codebuild-api"

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

resource "aws_iam_role_policy_attachment" "codebuild_ecs" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = "${aws_iam_role.codebuild.name}"
}
