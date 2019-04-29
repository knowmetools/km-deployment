output "production_admin_password" {
  sensitive = true
  value     = module.api_deploy_prod.admin_password
}

output "staging_admin_password" {
  sensitive = true
  value     = module.api_deploy_staging.admin_password
}
