terraform {
  backend "s3" {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/database"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/database"
  }
}

provider "postgresql" {
  database = "${data.terraform_remote_state.infrastructure.database_name}"
  host     = "${data.terraform_remote_state.infrastructure.database_host}"
  password = "${data.terraform_remote_state.infrastructure.database_admin_password}"
  port     = "${data.terraform_remote_state.infrastructure.database_port}"
  username = "${data.terraform_remote_state.infrastructure.database_admin_user}"
  version  = "~> 0.1"
}

data "terraform_remote_state" "infrastructure" {
  backend   = "s3"
  workspace = "${terraform.workspace}"

  config {
    bucket               = "km-tf-state"
    dynamodb_table       = "terraformLock"
    key                  = "know-me-api/infrastructure"
    region               = "us-east-1"
    workspace_key_prefix = "know-me-api/infrastructure"
  }
}

resource "postgresql_role" "db_user" {
  login    = true
  name     = "${data.terraform_remote_state.infrastructure.database_user}"
  password = "${data.terraform_remote_state.infrastructure.database_password}"
}
