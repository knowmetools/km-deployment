output "instance" {
  value = aws_db_instance.this
}

output "security_group" {
  value = aws_security_group.db
}
