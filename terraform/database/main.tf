terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/database"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/database"
  }
}

provider "postgresql" {
  database = data.terraform_remote_state.infrastructure.outputs.database_name
  host     = data.terraform_remote_state.infrastructure.outputs.database_host
  password = data.terraform_remote_state.infrastructure.outputs.database_admin_password
  port     = data.terraform_remote_state.infrastructure.outputs.database_port
  username = data.terraform_remote_state.infrastructure.outputs.database_admin_user
}

data "terraform_remote_state" "infrastructure" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/infrastructure"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/infrastructure"
  }
}

resource "postgresql_role" "db_user" {
  login    = true
  name     = data.terraform_remote_state.infrastructure.outputs.database_user
  password = data.terraform_remote_state.infrastructure.outputs.database_password
}

