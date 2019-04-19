output "ecr_repository" {
  value = aws_ecr_repository.api
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_execution_role" {
  value = aws_iam_role.api_task_execution_role
}

output "ecs_service_name" {
  value = aws_ecs_service.api.name
}

output "lb_listener" {
  value = aws_lb_listener.api
}

output "lb_target_group_1" {
  value = aws_lb_target_group.blue
}

output "lb_target_group_2" {
  value = aws_lb_target_group.green
}

output "load_balancer" {
  value = aws_lb.api
}

output "task_definition" {
  value = aws_ecs_task_definition.api
}

output "task_definition_file" {
  value = data.template_file.task_definition
}

output "task_definition_image_placeholder" {
  value = local.image_placeholder
}

output "task_role" {
  value = aws_iam_role.api_task_role
}

output "web_container_name" {
  value = local.api_web_container_name
}

output "web_container_port" {
  value = local.api_web_container_port
}

output "webserver_sg" {
  value = aws_security_group.api
}
