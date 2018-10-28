output "aws_region" {
  value = "${var.aws_region}"
}

output "database_host" {
  value = "${aws_db_instance.database.address}"
}

output "database_name" {
  value = "${aws_db_instance.database.name}"
}

output "database_password" {
  sensitive = true
  value     = "${postgresql_role.db_user.password}"
}

output "database_port" {
  value = "${aws_db_instance.database.port}"
}

output "database_user" {
  value = "${var.application_db_user}"
}

output "django_secret_key" {
  sensitive = true
  value     = "${random_string.django_secret_key.result}"
}

output "static_files_bucket" {
  value = "${aws_s3_bucket.static.id}"
}

output "webserver_domain" {
  value = "${aws_route53_record.web.fqdn}"
}
