output "api_ecs_execution_role" {
  value = aws_iam_role.api_task_execution_role.name
}

output "api_ecs_task_role" {
  value = aws_iam_role.api_task_role.name
}

output "api_elb_dns_name" {
  value = aws_lb.api.dns_name
}

output "api_elb_zone_id" {
  value = aws_lb.api.zone_id
}

