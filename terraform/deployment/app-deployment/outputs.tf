output "admin_password" {
  sensitive = true
  value     = random_string.admin_password.result
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.api.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.main.deployment_group_name
}
