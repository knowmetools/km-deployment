output "database_host" {
  value = "${aws_db_instance.database.address}"
}

output "database_name" {
  value = "${aws_db_instance.database.name}"
}

output "database_password" {
  sensitive = true
  value     = "${aws_db_instance.database.password}"
}

output "database_port" {
  value = "${aws_db_instance.database.port}"
}

output "database_user" {
  value = "${var.application_db_user}"
}

output "webserver_domain" {
  value = "${aws_route53_record.web.fqdn}"
}
