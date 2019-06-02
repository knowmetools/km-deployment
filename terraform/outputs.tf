output "production_admin_email" {
  value = var.admin_email
}

output "production_admin_password" {
  sensitive = true
  value     = module.deployment.production_admin_password
}

output "production_db_admin_password" {
  sensitive = true
  value     = module.prod_app.database_admin_password
}

output "production_db_admin_user" {
  value = module.prod_app.database_admin_user
}

output "production_db_password" {
  sensitive = true
  value     = module.prod_app.database_password
}

output "production_db_user" {
  value = module.prod_app.database_user
}

output "staging_admin_email" {
  value = var.admin_email
}

output "staging_admin_password" {
  sensitive = true
  value     = module.deployment.staging_admin_password
}

output "staging_db_admin_password" {
  sensitive = true
  value     = module.staging_app.database_admin_password
}

output "staging_db_admin_user" {
  value = module.staging_app.database_admin_user
}

output "staging_db_password" {
  sensitive = true
  value     = module.staging_app.database_password
}

output "staging_db_user" {
  value = module.staging_app.database_user
}
