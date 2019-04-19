# Application Terraform Configuration

This directory contains the Terraform configuration responsible for provisioning
the infrastructure required to serve the application itself.

## API

The API is composed of the following main components:

* RDS instance storing all API data
* ECS service running the API web servers as well as periodic background jobs
* S3 bucket storing user-uploaded media files

## Web Application

The web application is simply an S3 bucket that contains the static HTML and
JavaScript files that compose the application served through a CloudFront
distribution.
