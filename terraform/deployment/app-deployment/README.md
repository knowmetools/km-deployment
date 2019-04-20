# App Deployment

This module contains the Terraform configuration for deploying a specific
version of the app. It is intended to encapsulate the CodeDeploy infrastructure
responsible for handling the deployment step of the CodePipeline. By creating
this module, we can create similar configurations for deploying the staging and
production environments.
