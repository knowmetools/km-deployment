data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_vpc" "default" {
  default = true
}

module "api" {
  source = "./api"

  acm_certificate                   = var.api_acm_certificate
  app_name                          = "${var.app_name} API"
  app_slug                          = "${var.app_slug}-api"
  apple_km_premium_product_codes    = var.apple_km_premium_product_codes
  apple_receipt_validation_endpoint = var.apple_receipt_validation_endpoint
  apple_shared_secret               = var.apple_shared_secret
  base_tags                         = var.base_tags
  domain                            = var.api_domain
  environment                       = var.environment
  sentry_dsn                        = var.sentry_dsn
  ssm_parameter_prefix              = "${var.ssm_parameter_prefix}/api"
  subnet_ids                        = data.aws_subnet_ids.default.ids
  vpc_id                            = data.aws_vpc.default.id
  web_app_domain                    = var.web_app_domain
}

module "web_app" {
  source = "./cloudfront-dist"

  acm_certificate = var.web_app_acm_certificate
  app_name        = "${var.app_name} Web App"
  app_slug        = "${var.app_slug}-web-app"
  base_tags       = var.base_tags
  domain          = var.web_app_domain
}

################################################################################
#                                  DNS Records                                 #
################################################################################

resource "aws_route53_record" "api" {
  name    = var.api_domain
  type    = "A"
  zone_id = var.route_53_zone.id

  alias {
    name                   = module.api.load_balancer.dns_name
    zone_id                = module.api.load_balancer.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "web_app" {
  name    = var.web_app_domain
  type    = "A"
  zone_id = var.route_53_zone.id

  alias {
    name                   = module.web_app.cloudfront_dist.domain_name
    zone_id                = module.web_app.cloudfront_dist.hosted_zone_id
    evaluate_target_health = false
  }
}
