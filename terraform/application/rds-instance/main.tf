################################################################################
#                                 RDS Instance                                 #
################################################################################

resource "aws_db_instance" "this" {
  allocated_storage                   = var.storage_gb
  allow_major_version_upgrade         = var.allow_major_version_upgrade
  backup_retention_period             = var.backup_retention_period
  engine                              = var.engine
  final_snapshot_identifier           = "${var.name_slug}-final-snap"
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  identifier                          = "${var.name_slug}"
  instance_class                      = var.instance_type
  name                                = var.db_name
  password                            = random_string.admin_password.result
  port                                = var.port
  username                            = var.admin_user
  vpc_security_group_ids              = [aws_security_group.db.id]

  tags = merge(var.base_tags, { "Name" = var.name })
}

################################################################################
#                                Security Group                                #
################################################################################

resource "aws_security_group" "db" {
  name = "${var.name_slug}-sg"

  tags = merge(var.base_tags, { "Name" = var.name })
}

################################################################################
#                                    Secrets                                   #
################################################################################

resource "random_string" "admin_password" {
  length  = 32
  special = false
}
