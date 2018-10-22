terraform {
  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api"
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
  env       = "${terraform.workspace}"
  full_name = "${var.application_name} ${local.env}"
  subdomain = "${terraform.workspace == "production" ? "new-api" : "${terraform.workspace}.new-api"}"

  base_tags = {
    Application = "${var.application_name}"
    Environment = "${local.env}"
  }
}

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

data "aws_route53_zone" "main" {
  name = "${var.domain}"
}

data "template_file" "web_user_data" {
  template = "${file("${path.module}/templates/web_user_data.tpl")}"
}

################################################################################
#                                    Servers                                   #
################################################################################

resource "aws_db_instance" "database" {
  allocated_storage                   = "${var.database_storage}"
  allow_major_version_upgrade         = false
  backup_retention_period             = "${var.database_backup_window}"
  engine                              = "postgres"
  iam_database_authentication_enabled = true
  instance_class                      = "${var.database_instance_type}"
  name                                = "${var.database_name}"
  password                            = "${random_string.db_admin_password.result}"
  port                                = "${var.database_port}"
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
  from_port                = "${var.database_port}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.db.id}"
  source_security_group_id = "${aws_security_group.web.id}"
  to_port                  = "${var.database_port}"
  type                     = "ingress"
}

# Webserver Rules

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
  name    = "${local.subdomain}"
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
