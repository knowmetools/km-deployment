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
  region = var.aws_region
}

provider "github" {
  organization = "knowmetools"
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
  env            = terraform.workspace
  full_name      = "${var.application_name} ${title(local.env)}"
  full_name_slug = lower("${var.application_slug}-${local.env}")
  api_subdomain  = terraform.workspace == "production" ? "toolbox" : "${terraform.workspace}.toolbox"
  api_domain     = "${local.api_subdomain}.${var.domain}"
  web_domain     = terraform.workspace == "production" ? "app.${var.domain}" : "${terraform.workspace}.app.${var.domain}"

  base_tags = {
    Application = var.application_name
    Environment = title(local.env)
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
  app_name                          = local.full_name
  app_slug                          = local.full_name_slug
  apple_km_premium_product_codes    = var.apple_km_premium_product_codes
  apple_receipt_validation_endpoint = var.apple_receipt_validation_endpoints[var.apple_receipt_validation_mode]
  apple_shared_secret               = var.apple_shared_secret
  base_tags                         = local.base_tags
  environment                       = local.env
  route_53_zone                     = data.aws_route53_zone.main
  sentry_dsn                        = var.sentry_dsn
  ssm_parameter_prefix              = "/${var.application_slug}/${local.env}"
  web_app_acm_certificate           = data.aws_acm_certificate.web_app
  web_app_domain                    = local.web_domain
}

################################################################################
#                                  Deployment                                  #
################################################################################

module "deployment" {
  source = "./deployment"

  admin_email                           = var.admin_email
  api_ecr_repository                    = module.prod_app.api_ecr_repository
  api_ecs_cluster                       = module.prod_app.api_ecs_cluster
  api_lb_listener                       = module.prod_app.api_lb_listener
  api_lb_target_group_1                 = module.prod_app.api_lb_target_group_1
  api_lb_target_group_2                 = module.prod_app.api_lb_target_group_2
  api_migration_security_group_ids      = module.prod_app.api_security_group_ids
  api_migration_subnet_ids              = module.prod_app.api_subnets
  api_service_name                      = module.prod_app.api_service_name
  api_source_branch                     = var.api_source_branch
  api_source_repo                       = var.api_source_repo
  api_task_definition                   = module.prod_app.api_task_definition
  api_task_definition_file              = module.prod_app.api_task_definition_file
  api_task_definition_image_placeholder = module.prod_app.api_task_definition_image_placeholder
  api_url                               = "https://${local.api_domain}"
  api_web_container_name                = module.prod_app.api_web_container_name
  api_web_container_port                = module.prod_app.api_web_container_port
  app_name                              = local.full_name
  app_slug                              = local.full_name_slug
  base_tags                             = local.base_tags
  database_admin_password_ssm_param     = module.prod_app.database_admin_password_ssm_param
  database_admin_user                   = module.prod_app.database_admin_user
  database_password_ssm_param           = module.prod_app.database_password_ssm_param
  source_owner                          = var.github_organization
  ssm_parameter_prefix                  = "/${var.application_slug}/${local.env}"
  web_app_bucket                        = module.prod_app.web_app_s3_bucket
  web_app_source_branch                 = var.web_app_source_branch
  web_app_source_repo                   = var.web_app_source_repo
}

