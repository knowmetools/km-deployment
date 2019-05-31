terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "infrastructure.tfstate"
    region               = "us-east-1"
    workspace_key_prefix = "know-me"
  }
}

provider "archive" {
  version = "~> 1.1"
}

provider "aws" {
  region  = var.aws_region
  version = "~> 2.12"
}

provider "github" {
  organization = "knowmetools"
  version      = "~> 2.1"
}

provider "null" {
  version = "~> 2.0"
}

provider "random" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 2.1"
}

locals {
  is_production      = terraform.workspace == "production"
  env                = terraform.workspace
  app_name           = "${var.application_name} ${title(local.env)}"
  app_name_staging   = "${local.app_name} Staging"
  app_slug           = lower("${var.application_slug}-${local.env}")
  app_slug_staging   = "${local.app_slug}-staging"
  api_domain         = local.is_production ? "toolbox.${var.domain}" : "${terraform.workspace}.toolbox.${var.domain}"
  api_domain_staging = local.is_production ? "staging.toolbox.${var.domain}" : "${local.env}-staging.toolbox.${var.domain}"
  # TODO: Properly pass this to the application module
  task_definition_image_placeholder = "IMAGE"
  web_domain                        = local.is_production ? "app.${var.domain}" : "${local.env}.app.${var.domain}"
  web_domain_staging                = local.is_production ? "staging.app.${var.domain}" : "${local.env}-staging.app.${var.domain}"

  base_tags = {
    Application = var.application_name
  }
}

data "aws_acm_certificate" "api" {
  domain = "toolbox.knowmetools.com"
}

data "aws_acm_certificate" "web_app" {
  domain = "app.knowmetools.com"
}

data "aws_route53_zone" "main" {
  name = var.domain
}

################################################################################
#                                  Application                                 #
################################################################################

module "prod_app" {
  source = "./application"

  api_acm_certificate               = data.aws_acm_certificate.api
  api_domain                        = local.api_domain
  app_name                          = local.app_name
  app_slug                          = local.app_slug
  apple_km_premium_product_codes    = var.apple_km_premium_product_codes
  apple_receipt_validation_endpoint = var.apple_receipt_validation_endpoints[var.apple_receipt_validation_mode]
  apple_shared_secret               = var.apple_shared_secret
  base_tags                         = merge(local.base_tags, { Environment = title(local.env) })
  environment                       = local.env
  route_53_zone                     = data.aws_route53_zone.main
  sentry_dsn                        = var.sentry_dsn
  ssm_parameter_prefix              = "/${var.application_slug}/${local.env}/production"
  web_app_acm_certificate           = data.aws_acm_certificate.web_app
  web_app_domain                    = local.web_domain
}

module "staging_app" {
  source = "./application"

  api_acm_certificate               = data.aws_acm_certificate.api
  api_domain                        = local.api_domain_staging
  app_name                          = local.app_name_staging
  app_slug                          = local.app_slug_staging
  apple_km_premium_product_codes    = var.apple_km_premium_product_codes
  apple_receipt_validation_endpoint = var.apple_receipt_validation_endpoints[var.apple_receipt_validation_mode]
  apple_shared_secret               = var.apple_shared_secret
  base_tags                         = merge(local.base_tags, { Environment = "${title(local.env)} - Staging" })
  environment                       = "${local.env}-staging"
  route_53_zone                     = data.aws_route53_zone.main
  sentry_dsn                        = var.sentry_dsn
  ssm_parameter_prefix              = "/${var.application_slug}/${local.env}/staging"
  web_app_acm_certificate           = data.aws_acm_certificate.web_app
  web_app_domain                    = local.web_domain_staging
}

################################################################################
#                                  Deployment                                  #
################################################################################

module "deployment" {
  source = "./deployment"

  admin_email                           = var.admin_email
  api_source_branch                     = var.api_source_branch
  api_source_repo                       = var.api_source_repo
  api_task_definition_image_placeholder = local.task_definition_image_placeholder
  app_name                              = local.app_name
  app_slug                              = local.app_slug
  base_tags                             = merge(local.base_tags, { Environment = title(local.env) })
  source_owner                          = var.github_organization
  ssm_parameter_prefix                  = "/${var.application_slug}/${local.env}"
  web_app_source_branch                 = var.web_app_source_branch
  web_app_source_repo                   = var.web_app_source_repo

  api_prod = {
    database_admin_password_ssm_param = module.prod_app.database_admin_password_ssm_param
    database_admin_user               = module.prod_app.database_admin_user
    ecs_cluster                       = module.prod_app.api_ecs_cluster
    ecs_service                       = module.prod_app.api_service_name
    lb_listener_arn                   = module.prod_app.api_lb_listener.arn
    lb_target_group_1                 = module.prod_app.api_lb_target_group_1.name
    lb_target_group_2                 = module.prod_app.api_lb_target_group_2.name
    migration_security_group_ids      = module.prod_app.api_security_group_ids
    migration_subnet_ids              = module.prod_app.api_subnets
    task_definition_content           = module.prod_app.api_task_definition_file.rendered
    task_definition_family            = module.prod_app.api_task_definition.family
    url                               = "https://${local.api_domain}"
    web_container_name                = module.prod_app.api_web_container_name
    web_container_port                = module.prod_app.api_web_container_port
  }

  api_staging = {
    database_admin_password_ssm_param = module.staging_app.database_admin_password_ssm_param
    database_admin_user               = module.staging_app.database_admin_user
    ecs_cluster                       = module.staging_app.api_ecs_cluster
    ecs_service                       = module.staging_app.api_service_name
    lb_listener_arn                   = module.staging_app.api_lb_listener.arn
    lb_target_group_1                 = module.staging_app.api_lb_target_group_1.name
    lb_target_group_2                 = module.staging_app.api_lb_target_group_2.name
    migration_security_group_ids      = module.staging_app.api_security_group_ids
    migration_subnet_ids              = module.staging_app.api_subnets
    task_definition_content           = module.staging_app.api_task_definition_file.rendered
    task_definition_family            = module.staging_app.api_task_definition.family
    url                               = "https://${local.api_domain_staging}"
    web_container_name                = module.staging_app.api_web_container_name
    web_container_port                = module.staging_app.api_web_container_port
  }

  web_app_prod = {
    s3_bucket = module.prod_app.web_app_s3_bucket
  }

  web_app_staging = {
    s3_bucket = module.staging_app.web_app_s3_bucket
  }
}

