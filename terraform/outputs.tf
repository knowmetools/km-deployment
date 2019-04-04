output "api_url" {
  value = aws_route53_record.web.fqdn
}

output "aws_region" {
  value = var.aws_region
}

output "database_admin_password" {
  sensitive = true
  value     = aws_db_instance.database.password
}

output "database_admin_user" {
  sensitive = true
  value     = aws_db_instance.database.username
}

output "database_host" {
  value = aws_db_instance.database.address
}

output "database_name" {
  value = aws_db_instance.database.name
}

output "database_password" {
  sensitive = true
  value     = random_string.db_password.result
}

output "database_port" {
  value = aws_db_instance.database.port
}

output "database_user" {
  value = var.application_db_user
}

output "django_admin_email" {
  value = var.django_admin_email
}

output "django_admin_password" {
  sensitive = true
  value     = random_string.django_admin_password.result
}

output "webapp_url" {
  value = module.webapp.cloudfront_url
}

