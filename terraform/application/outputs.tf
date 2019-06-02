output "api_ecs_cluster" {
  value = module.api.ecs_cluster
}

output "api_lb_listener" {
  value = module.api.lb_listener
}

output "api_lb_target_group_1" {
  value = module.api.lb_target_group_1
}

output "api_lb_target_group_2" {
  value = module.api.lb_target_group_2
}

output "api_security_group_ids" {
  value = module.api.security_group_ids
}

output "api_service_name" {
  value = module.api.service_name
}

output "api_subnets" {
  value = data.aws_subnet_ids.default.ids
}

output "api_task_definition" {
  value = module.api.task_definition
}

output "api_task_definition_file" {
  value = module.api.task_definition_file
}

output "api_task_definition_image_placeholder" {
  value = module.api.task_definition_image_placeholder
}

output "api_web_container_name" {
  value = module.api.web_container_name
}

output "api_web_container_port" {
  value = module.api.web_container_port
}

output "database_admin_password" {
  sensitive = true
  value     = module.api.database_admin_password
}

output "database_admin_password_ssm_param" {
  value = module.api.database_admin_password_ssm_param
}

output "database_admin_user" {
  value = module.api.database_admin_user
}

output "database_password" {
  sensitive = true
  value     = module.api.database_password
}

output "database_password_ssm_param" {
  value = module.api.database_password_ssm_param
}

output "database_user" {
  value = module.api.database_user
}

output "web_app_s3_bucket" {
  value = module.web_app.s3_bucket
}
