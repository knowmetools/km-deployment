terraform {
  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/infrastructure"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/infrastructure"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 1.41"
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
  web_domain     = "${terraform.workspace == "production" ? "app.${var.domain}" : "${terraform.workspace}.app.${var.domain}"}"

  base_tags = {
    Application = "${var.application_name}"
    Environment = "${local.env}"
  }
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

data "template_file" "web_user_data" {
  template = "${file("${path.module}/templates/web_user_data.tpl")}"
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

resource "aws_instance" "webserver" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.web.name}"
  instance_type          = "${var.webserver_instance_type}"
  user_data              = "${data.template_file.web_user_data.rendered}"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]

  tags = "${merge(
    local.base_tags,
    map(
      "Name", "${local.full_name} Webserver",
      "Role", "Webserver"
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
  records = ["${aws_instance.webserver.public_ip}"]
  ttl     = 60
  zone_id = "${data.aws_route53_zone.main.id}"
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

  keepers {
    instance_id = "${aws_instance.webserver.id}"
  }
}

resource "random_string" "django_secret_key" {
  length = 50

  keepers {
    instance_id = "${aws_instance.webserver.id}"
  }
}

################################################################################
#                                 IAM Policies                                 #
################################################################################

resource "aws_iam_instance_profile" "web" {
  role = "${aws_iam_role.web.name}"
}

resource "aws_iam_role" "web" {
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
  description        = "Role for ${var.application_name} webservers."
}

resource "aws_iam_role_policy_attachment" "webserver" {
  policy_arn = "${aws_iam_policy.webserver.arn}"
  role       = "${aws_iam_role.web.name}"
}

resource "aws_iam_policy" "webserver" {
  description = "Grants webservers access to Cloudfront, SES, and static files on S3."

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
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads",
        "s3:ListBucketVersions"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.static.id}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*Object*",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.static.id}/*"
    }
  ]
}
EOF
}
