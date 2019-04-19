module "db" {
  source = "../rds-instance"

  base_tags = var.base_tags
  db_name   = var.database_name
  name      = "${var.app_name} Database"
  name_slug = "${var.app_slug}"
}

data "aws_region" "current" {}

module "api_cluster" {
  source = "../api-cluster"

  app_slug        = var.app_slug
  aws_region      = data.aws_region.current.name
  certificate_arn = var.acm_certificate.arn
  subnet_ids      = var.subnet_ids
  vpc_id          = var.vpc_id

  # Environment
  api_environment = [
    {
      name  = "DJANGO_ALLOWED_HOSTS"
      value = var.domain
    },
    {
      name  = "DJANGO_APPLE_PRODUCT_CODES_KNOW_ME_PREMIUM"
      value = var.apple_km_premium_product_codes
    },
    {
      name  = "DJANGO_APPLE_RECEIPT_VALIDATION_ENDPOINT"
      value = var.apple_receipt_validation_endpoint
    },
    {
      name  = "DJANGO_APPLE_SHARED_SECRET"
      value = var.apple_shared_secret
    },
    {
      name  = "DJANGO_AWS_REGION"
      value = data.aws_region.current.name
    },
    {
      name  = "DJANGO_DB_HOST"
      value = module.db.instance.address
    },
    {
      name  = "DJANGO_DB_NAME"
      value = module.db.instance.name
    },
    {
      name  = "DJANGO_DB_PORT"
      value = module.db.instance.port
    },
    {
      name  = "DJANGO_DB_USER"
      value = var.application_db_user
    },
    {
      name  = "DJANGO_EMAIL_VERIFICATION_URL"
      value = "https://${var.web_app_domain}/verify-email/{key}"
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
      value = "https://${var.web_app_domain}/reset-password/{key}"
    },
    {
      name  = "DJANGO_S3_BUCKET"
      value = aws_s3_bucket.static.bucket
    },
    {
      name  = "DJANGO_S3_STORAGE"
      value = "True"
    },
    {
      name  = "DJANGO_SENTRY_DSN"
      value = var.sentry_dsn
    },
    {
      name  = "DJANGO_SENTRY_ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "DJANGO_SES_ENABLED"
      value = "True"
    },
  ]

  api_secrets = [
    {
      name      = "DJANGO_DB_PASSWORD"
      valueFrom = aws_ssm_parameter.db_password.arn
    },
    {
      name      = "DJANGO_SECRET_KEY"
      valueFrom = aws_ssm_parameter.django_secret_key.arn
    },
  ]
}

################################################################################
#                                   Firewall                                   #
################################################################################

resource "aws_wafregional_web_acl_association" "lb" {
  resource_arn = module.api_cluster.load_balancer.arn
  web_acl_id   = aws_wafregional_web_acl.api.id
}

resource "aws_wafregional_web_acl" "api" {
  name        = replace(var.app_name, " ", "")
  metric_name = replace(var.app_name, " ", "")

  default_action {
    type = "BLOCK"
  }

  rule {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id  = aws_wafregional_rule.api_hosts.id
  }
}

resource "aws_wafregional_rule" "api_hosts" {
  metric_name = "${replace(var.app_name, " ", "")}Hosts"
  name        = "${replace(var.app_name, " ", "")}Hosts"

  predicate {
    data_id = aws_wafregional_byte_match_set.api_host.id
    negated = false
    type    = "ByteMatch"
  }
}

resource "aws_wafregional_byte_match_set" "api_host" {
  name = "${var.app_slug}-matches-host"

  byte_match_tuples {
    text_transformation   = "LOWERCASE"
    target_string         = var.domain
    positional_constraint = "EXACTLY"

    field_to_match {
      type = "HEADER"
      data = "host"
    }
  }
}

################################################################################
#                           Security Groups and Rules                          #
################################################################################

resource "aws_security_group_rule" "db_in_api" {
  description              = "Allow connections from API web servers."
  from_port                = module.db.instance.port
  protocol                 = "tcp"
  security_group_id        = module.db.security_group.id
  source_security_group_id = module.api_cluster.webserver_sg.id
  to_port                  = module.db.instance.port
  type                     = "ingress"
}

resource "aws_security_group_rule" "api_out_db" {
  description              = "Allow outgoing database connections."
  from_port                = module.db.instance.port
  protocol                 = "tcp"
  security_group_id        = module.api_cluster.webserver_sg.id
  source_security_group_id = module.db.security_group.id
  to_port                  = module.db.instance.port
  type                     = "egress"
}

################################################################################
#                                   S3 Bucket                                  #
################################################################################

resource "aws_s3_bucket" "static" {
  acl           = "public-read"
  bucket        = "${var.app_slug}-static"
  force_destroy = true

  tags = merge(
    var.base_tags,
    {
      Name = "${var.app_name} Static Files"
    },
  )

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

################################################################################
#                               Secret Generation                              #
################################################################################

resource "random_string" "db_password" {
  length  = 32
  special = false

  keepers = {
    database_id = module.db.instance.id
  }
}

resource "random_string" "django_admin_password" {
  length = 32
}

resource "random_string" "django_secret_key" {
  length = 50
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

resource "aws_ssm_parameter" "db_admin_password" {
  name  = "${var.ssm_parameter_prefix}/db/admin-password"
  type  = "SecureString"
  value = module.db.instance.password
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${var.ssm_parameter_prefix}/db/password"
  type  = "SecureString"
  value = random_string.db_password.result
}

resource "aws_ssm_parameter" "django_admin_password" {
  name  = "${var.ssm_parameter_prefix}/django/admin-password"
  type  = "SecureString"
  value = random_string.django_admin_password.result
}

resource "aws_ssm_parameter" "django_secret_key" {
  name  = "${var.ssm_parameter_prefix}/django/secret-key"
  type  = "SecureString"
  value = random_string.django_secret_key.result
}

################################################################################
#                                 IAM Policies                                 #
################################################################################

resource "aws_iam_role_policy_attachment" "api_s3" {
  policy_arn = aws_iam_policy.api_s3.arn
  role       = module.api_cluster.task_role.name
}

resource "aws_iam_policy" "api_s3" {
  description = "Grants API tasks access to S3."
  name        = "${var.app_slug}-s3-access"
  policy      = data.aws_iam_policy_document.api_s3.json
}

data "aws_iam_policy_document" "api_s3" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucketVersions",
    ]
    resources = [aws_s3_bucket.static.arn]
  }

  statement {
    actions = [
      "s3:*Object*",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.static.arn}/*"]
  }
}

resource "aws_iam_role_policy_attachment" "api_ses" {
  policy_arn = aws_iam_policy.api_ses.arn
  role       = module.api_cluster.task_role.name
}

resource "aws_iam_policy" "api_ses" {
  description = "Grants API tasks access to SES to send emails."
  name        = "${var.app_slug}-ses-access"
  policy      = data.aws_iam_policy_document.api_ses.json
}

data "aws_iam_policy_document" "api_ses" {
  statement {
    actions = [
      "ses:GetSendQuota",
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}
