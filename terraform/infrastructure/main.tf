terraform {
  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/infrastructure"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/infrastructure"
  }
}

provider "archive" {
  version = "~> 1.1"
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 1.59"
}

provider "github" {
  organization = "knowmetools"
  version      = "~> 1.3"
}

provider "null" {
  version = "~> 2.0"
}

provider "random" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 1.0"
}

locals {
  env            = "${terraform.workspace}"
  full_name      = "${var.application_name} ${local.env}"
  full_name_slug = "${lower(replace(local.full_name, " ", "-"))}"
  api_subdomain  = "${terraform.workspace == "production" ? "toolbox" : "${terraform.workspace}.toolbox"}"
  api_domain     = "${local.api_subdomain}.${var.domain}"
  web_domain     = "${terraform.workspace == "production" ? "app.${var.domain}" : "${terraform.workspace}.app.${var.domain}"}"

  base_tags = {
    Application = "${var.application_name}"
    Environment = "${local.env}"
  }
}

data "aws_acm_certificate" "api" {
  domain = "toolbox.knowmetools.com"
}

data "aws_acm_certificate" "webapp" {
  domain = "app.knowmetools.com"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_route53_zone" "main" {
  name = "${var.domain}"
}

################################################################################
#                                   Web App                                    #
################################################################################

module "webapp" {
  source = "./cloudfront-dist"

  acm_certificate_arn = "${data.aws_acm_certificate.webapp.arn}"
  application         = "Know Me Webapp ${terraform.workspace}"
  domain              = "${local.web_domain}"
  domain_zone_id      = "${data.aws_route53_zone.main.id}"
}

module "webapp_build" {
  source = "./webapp-codebuild"

  api_root          = "https://${local.api_domain}"
  app_slug          = "${local.full_name_slug}"
  base_tags         = "${local.base_tags}"
  deploy_bucket     = "${module.webapp.s3_bucket}"
  source_repository = "km-web"
}

################################################################################
#                              API Docker Cluster                              #
################################################################################

module "api_cluster" {
  source = "api-cluster"

  app_slug        = "km-${local.env}-api"
  aws_region      = "${var.aws_region}"
  certificate_arn = "${data.aws_acm_certificate.api.arn}"

  # Environment
  api_environment = [
    {
      name  = "DJANGO_ALLOWED_HOSTS"
      value = "${local.api_domain}"
    },
    {
      name  = "DJANGO_APPLE_PRODUCT_CODES_KNOW_ME_PREMIUM"
      value = "${var.apple_km_premium_product_codes}"
    },
    {
      name  = "DJANGO_APPLE_RECEIPT_VALIDATION_ENDPOINT"
      value = "${lookup(var.apple_receipt_validation_endpoints, var.apple_receipt_validation_mode)}"
    },
    {
      name  = "DJANGO_APPLE_SHARED_SECRET"
      value = "${var.apple_shared_secret}"
    },
    {
      name  = "DJANGO_AWS_REGION"
      value = "${var.aws_region}"
    },
    {
      name  = "DJANGO_DB_HOST"
      value = "${aws_db_instance.database.address}"
    },
    {
      name  = "DJANGO_DB_NAME"
      value = "${aws_db_instance.database.name}"
    },
    {
      name  = "DJANGO_DB_PORT"
      value = "${aws_db_instance.database.port}"
    },
    {
      name  = "DJANGO_DB_USER"
      value = "${var.application_db_user}"
    },
    {
      name  = "DJANGO_EMAIL_VERIFICATION_URL"
      value = "https://${module.webapp.cloudfront_url}/verify-email/{key}"
    },
    {
      name  = "DJANGO_HTTPS"
      value = "True"
    },
    {
      name  = "DJANGO_HTTPS_LOAD_BALANCER"
      value = "True"
    },
    {
      name  = "DJANGO_PASSWORD_RESET_URL"
      value = "https://${module.webapp.cloudfront_url}/reset-password/{key}"
    },
    {
      name  = "DJANGO_S3_BUCKET"
      value = "${aws_s3_bucket.static.bucket}"
    },
    {
      name  = "DJANGO_S3_STORAGE"
      value = "True"
    },
    {
      name  = "DJANGO_SENTRY_DSN"
      value = "${var.sentry_dsn}"
    },
    {
      name  = "DJANGO_SENTRY_ENVIRONMENT"
      value = "${local.env}"
    },
    {
      name  = "DJANGO_SES_ENABLED"
      value = "True"
    },
  ]

  api_secrets = [
    {
      name      = "DJANGO_DB_PASSWORD"
      valueFrom = "${aws_ssm_parameter.db_password.arn}"
    },
    {
      name      = "DJANGO_SECRET_KEY"
      valueFrom = "${aws_ssm_parameter.db_password.arn}"
    },
  ]
}

################################################################################
#                                    Servers                                   #
################################################################################

resource "aws_db_instance" "database" {
  allocated_storage                   = "${var.database_storage}"
  allow_major_version_upgrade         = false
  backup_retention_period             = "${var.database_backup_window}"
  engine                              = "postgres"
  final_snapshot_identifier           = "${local.full_name_slug}-final"
  iam_database_authentication_enabled = true
  instance_class                      = "${var.database_instance_type}"
  name                                = "${var.database_name}"
  password                            = "${random_string.db_admin_password.result}"
  port                                = "${var.database_port}"
  publicly_accessible                 = true
  username                            = "${var.database_admin_user}"
  vpc_security_group_ids              = ["${aws_security_group.db.id}"]

  tags = "${merge(
    local.base_tags,
    map(
        "Name", local.full_name
    )
  )}"
}

################################################################################
#                                 Static Files                                 #
################################################################################

resource "aws_s3_bucket" "static" {
  acl           = "public-read"
  bucket_prefix = "${local.full_name_slug}-static"
  force_destroy = true
  region        = "${var.aws_region}"

  tags = "${merge(
    local.base_tags,
    map(
        "Name", "${local.full_name} Static Files"
    )
  )}"

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

################################################################################
#                                Security Groups                               #
################################################################################

resource "aws_security_group" "db" {
  tags = "${merge(
    local.base_tags,
    map(
      "Name", "${local.full_name} Databases"
    )
  )}"
}

resource "aws_security_group" "web" {
  tags = "${merge(
    local.base_tags,
    map(
      "Name", "${local.full_name} Webservers"
    )
  )}"
}

# Database Rules

resource "aws_security_group_rule" "db_ingress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = "${var.database_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.db.id}"

  //  source_security_group_id = "${aws_security_group.web.id}"
  to_port = "${var.database_port}"
  type    = "ingress"
}

# Webserver Rules

resource "aws_security_group_rule" "web_database" {
  from_port                = "${var.database_port}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.web.id}"
  source_security_group_id = "${aws_security_group.db.id}"
  to_port                  = "${var.database_port}"
  type                     = "egress"
}

resource "aws_security_group_rule" "web_out" {
  count = "${length(var.webserver_sg_rules)}"

  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = "${element(var.webserver_sg_rules, count.index)}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.web.id}"
  to_port           = "${element(var.webserver_sg_rules, count.index)}"
  type              = "egress"
}

resource "aws_security_group_rule" "web_in" {
  count = "${length(var.webserver_sg_rules)}"

  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = "${element(var.webserver_sg_rules, count.index)}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.web.id}"
  to_port           = "${element(var.webserver_sg_rules, count.index)}"
  type              = "ingress"
}

resource "aws_security_group_rule" "web_ssh" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.web.id}"
  to_port           = 22
  type              = "ingress"
}

################################################################################
#                                  DNS Records                                 #
################################################################################

resource "aws_route53_record" "web" {
  name    = "${local.api_subdomain}"
  type    = "A"
  zone_id = "${data.aws_route53_zone.main.id}"

  alias {
    name                   = "${module.api_cluster.api_elb_dns_name}"
    zone_id                = "${module.api_cluster.api_elb_zone_id}"
    evaluate_target_health = false
  }
}

################################################################################
#                               Secret Generation                              #
################################################################################

resource "random_string" "db_admin_password" {
  length  = 32
  special = false
}

resource "random_string" "db_password" {
  length  = 32
  special = false

  keepers {
    database_id = "${aws_db_instance.database.id}"
  }
}

resource "random_string" "django_admin_password" {
  length = 32
}

resource "random_string" "django_secret_key" {
  length = 50
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/km-api/${local.env}/db/password"
  type  = "SecureString"
  value = "${random_string.db_password.result}"
}

resource "aws_ssm_parameter" "django_secret_key" {
  name  = "/km-api/${local.env}/django/secret-key"
  type  = "SecureString"
  value = "${random_string.django_secret_key.result}"
}

################################################################################
#                                 IAM Policies                                 #
################################################################################

resource "aws_iam_role_policy_attachment" "api_s3" {
  policy_arn = "${aws_iam_policy.api_s3.arn}"
  role       = "${module.api_cluster.api_ecs_task_role}"
}

resource "aws_iam_policy" "api_s3" {
  description = "Grants API tasks access to S3."
  name        = "${local.full_name_slug}-api-s3-access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads",
        "s3:ListBucketVersions"
      ],
      "Resource": "${aws_s3_bucket.static.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*Object*",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "${aws_s3_bucket.static.arn}/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api_ses" {
  policy_arn = "${aws_iam_policy.api_ses.arn}"
  role       = "${module.api_cluster.api_ecs_task_role}"
}

resource "aws_iam_policy" "api_ses" {
  description = "Grants API tasks access to SES to send emails."
  name        = "${local.full_name_slug}-api-ses-access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ses:GetSendQuota",
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}
