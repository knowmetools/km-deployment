output "database_admin_password" {
  sensitive = true
  value     = "${random_string.db_admin_password.result}"
}

output "database_admin_user" {
  value = "${var.database_admin_user}"
}

output "database_host" {
  value = "${aws_db_instance.database.address}"
}

output "database_port" {
  value = "${aws_db_instance.database.port}"
}

output "webserver_domain" {
  value = "${aws_route53_record.web.fqdn}"
}
