output "production_admin_email" {
  value = var.admin_email
}

output "production_admin_password" {
  sensitive = true
  value     = module.deployment.production_admin_password
}

output "staging_admin_email" {
  value = var.admin_email
}

output "staging_admin_password" {
  sensitive = true
  value     = module.deployment.staging_admin_password
}
