output "project_name" {
  value = aws_codebuild_project.this.name
}

output "service_role" {
  value = aws_iam_role.codebuild.name
}

