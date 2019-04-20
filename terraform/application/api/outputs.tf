output "database_admin_password_ssm_param" {
  value = aws_ssm_parameter.db_admin_password
}

output "database_admin_user" {
  value = module.db.instance.username
}

output "database_password_ssm_param" {
  value = aws_ssm_parameter.db_password
}

output "ecs_cluster" {
  value = module.api_cluster.ecs_cluster
}

output "lb_listener" {
  value = module.api_cluster.lb_listener
}

output "lb_target_group_1" {
  value = module.api_cluster.lb_target_group_1
}

output "lb_target_group_2" {
  value = module.api_cluster.lb_target_group_2
}

output "load_balancer" {
  value = module.api_cluster.load_balancer
}

output "security_group_ids" {
  value = [module.api_cluster.webserver_sg.id]
}

output "service_name" {
  value = module.api_cluster.ecs_service_name
}

output "task_definition" {
  value = module.api_cluster.task_definition
}

output "task_definition_file" {
  value = module.api_cluster.task_definition_file
}

output "task_definition_image_placeholder" {
  value = module.api_cluster.task_definition_image_placeholder
}

output "web_container_name" {
  value = module.api_cluster.web_container_name
}

output "web_container_port" {
  value = module.api_cluster.web_container_port
}
