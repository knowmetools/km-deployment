# Know Me Deployment

Deployment process for the entire Know Me app ecosystem. Infrastructure is
managed with [Terraform][terraform].

<!--
TOC managed by https://github.com/ekalinin/github-markdown-toc. Please do not
edit it directly.
-->

## Table of Contents

<!--ts-->
   * [Know Me Deployment](#know-me-deployment)
      * [Table of Contents](#table-of-contents)
      * [Overview](#overview)
      * [Provisioning](#provisioning)
         * [Prerequisites](#prerequisites)
         * [Updating the Infrastructure](#updating-the-infrastructure)
      * [Architecture](#architecture)
         * [Application](#application)
            * [API](#api)
            * [Web Application](#web-application)
         * [Deployment](#deployment)
            * [Building Application Versions](#building-application-versions)
            * [Deploying a Version](#deploying-a-version)
      * [Design Decisions and Quirks](#design-decisions-and-quirks)
         * [Pipeline from Staging to Production](#pipeline-from-staging-to-production)
         * [Lambda Function for Database Migrations](#lambda-function-for-database-migrations)
         * [API Background Job Invocation](#api-background-job-invocation)
         * [Building the Web Application Twice](#building-the-web-application-twice)
      * [Troubleshooting](#troubleshooting)
         * [Changing the Source Repository Branch](#changing-the-source-repository-branch)
      * [Migrations Involving the Database or Media Files](#migrations-involving-the-database-or-media-files)
         * [DB Migration](#db-migration)
            * [State Removal](#state-removal)
            * [Backup](#backup)
            * [Create New Database](#create-new-database)
            * [Create Role](#create-role)
            * [Restore Data](#restore-data)
            * [Delete Old Database](#delete-old-database)
         * [S3 Migration](#s3-migration)
            * [Terraform State Removal](#terraform-state-removal)
            * [Create New Bucket](#create-new-bucket)
            * [Copy Over Files](#copy-over-files)
            * [Delete Old Bucket](#delete-old-bucket)
      * [License](#license)

<!-- Added by: chathan, at: Wed May  1 12:23:38 EDT 2019 -->

<!--te-->

## Overview

This project is responsible for deploying all portions of the Know Me
application that are available over the internet. For now these pieces include
the [API][know-me-api] and [web app][know-me-web-app].

We try to follow the philosophy of infrastructure being immutable and
disposable. This manifests itself in our API being deployed as an ECS service
that is self healing. The web application is deployed to an S3 bucket published
using CloudFront.

In terms of deploying new application versions, we try to maintain a continuous
integration and deployment approach. The source repositories for these projects
are monitored and we use a combination of CodeBuild, CodePipeline, and
CodeDeploy to publish new versions.

## Provisioning

### Prerequisites

* Terraform must be [downloaded][terraform-download] and accessible on your
  `$PATH`. *Note we require Terraform 0.12+.*
* You must have AWS credentials granting administrative access.

### Updating the Infrastructure

We use Terraform's concept of workspaces to separate our environments. Because
of this, it is crucial you are on the correct workspace before applying changes.
By convention we use the `production` workspace for our production
infrastructure. All other workspaces can be spun up and down as desired.

Here is an example of updating the infrastructure for the staging environment.

```
terraform workspace select staging
terraform plan -out tfplan

# After reviewing the plan to make sure there are no unexpected changes:
terraform apply tfplan
```

## Architecture

There are two main components that are provisioned in this repository. The first
is the infrastructure for the application itself. This includes components such
as the ECS cluster running the API or the CloudFront distribution that serves
the web app. The second component that is provisioned is the continuous
integration and deployment pipeline responsible for deploying changes pushed to
the source repositories into staging and then production.

### Application

Architecturally, the application is currently split into two pieces, the API and
web application, each of which are stored in separate source repositories.

#### API

[Source Repository][know-me-api]

The core of the API is the ECS service running the web servers that process
incoming requests. Data is persisted in an RDS instance and user-uploaded files
are stored in an S3 bucket.

Outside the synchronous environment of the web servers, we also have a lambda
function triggered periodically that runs a new ECS task that performs
background jobs such as updating subscription statuses or cleaning up unneeded
records.

#### Web Application

[Source Repository][know-me-web-app]

The web application is simply a set of static HTML and JavaScript files that are
built and deployed to an S3 bucket that is served through a CloudFront
distribution.

### Deployment

Our deployment process is responsible for watching all source repositories for
changes, building new versions, and then promoting those builds from the staging
to production environment.

The overall pipeline looks like:

1. Pull source files for API and web application.
2. Build API and web application.
3. Deploy built versions to staging environment.
4. Deploy built versions to production environment.

#### Building Application Versions

We have two CodeBuild projects set up, one for the API and one for the web
application.

The API build process is responsible for building the Docker image used to run
the API's web servers, database migration tasks, and background jobs.

The web application build process compiles the app into static files that are
then output from the build in an archive file.

#### Deploying a Version

To deploy the API, we use CodeDeploy's integration with ECS to perform a
blue/green deployment. Using the Docker image version output by the API build
step, we can deploy a new set of web servers with the updated image. Prior to
the new web servers being deployed, we use a Lambda function to run the
migration tasks necessary before the new API version can be run.

The deployment of the web application is much simpler as we use CodePipeline's
integration with S3 to simply deploy the static files output by the web
application's build step.

The same process is used to deploy to the staging and production environments
with the only difference being the resources that are targeted.

## Design Decisions and Quirks

Here we hope to explain some of the rationale behind the design decisions made
in this repository.

### Pipeline from Staging to Production

Hopefully the benefits of a single pipeline that handles building a new
application version and then promoting it from the staging to production
environment are clear, but we will also explain one of the major reasons that
influenced our decision to do this.

In the past we have had a manually run deployment process required when
releasing a new application version. Even though the process itself was
automated (through a mix of Terraform and Ansible) we discovered that there was
a fairly high burden to actually starting the process due to the abundance of
configuration information that had to be provided. An example of this type of
information is any third-party service credentials. Any time we launched a
build, we would have to have that information on hand.

This led to a practice where small changes were not immediately deployed because
the time-cost of running a deployment outweighed the benefit of the change.

Hopefully our new pipeline changes that. While the configuration information
still has to be passed in when we provision the infrastructure in this
repository, we no longer need it when deploying an application version. Since
the application changes much more frequently than the configuration contained
here, hopefully this will save a lot of developer/engineer time.

### Lambda Function for Database Migrations

In nearly any application interacting with a SQL database, the deployment
process must consider how to migrate the database in order to be compatible with
the new application version.

The trouble in our case is that it is rather difficult to gain access to the
Docker image version of the API that is being deployed. The only location in the
CodeDeploy process where we get to insert custom code is through lambda
functions that are [invoked as hooks][codedeploy-ecs-hooks].

The next challenge we have to tackle is how to get the version of the Docker
image we want to run the migrations from when the only information provided to
the hook is the ID of the deployment. The
[source code of the migration Lambda][lambda-migration] shows how that is done.
Finally we launch a modified version of the ECS task for the API web servers
being deployed that has its command overridden to run the migrations.

The last piece of the puzzle is how to handle the asynchronous nature of the
database migration. Since the Lambda function mentioned above only starts the
migration task, we don't know if it has finished by the time the new web servers
have been provisioned. [This article][ecs-database-migration] describes a shift
in thinking that helps to understand how to deal with this type of task within
the context of an ECS environment. Specifically, we use the health check
mentioned in the article to prevent any web servers running the new application
version from receiving traffic before the associated migrations are run.

### API Background Job Invocation

Since our background jobs are run on ECS, they seem like a perfect candidate for
ECS' scheduled tasks. However, our deployment method complicates things in that
we do not have a specific task definition to run because new task definitions
are constantly created by our deployment process.

To solve this, we use a CloudWatch periodic event to trigger a Lambda function
that looks at the API service and pulls the Docker image being used by the API
and runs the background jobs on that image.

### Building the Web Application Twice

If we inspect the CodePipeline responsible for deployments, we can see that we
actually build the web application twice; once for staging and once for
production. This is because the API that the application interacts with is
baked in at build time, so we have to build a version for each environment.

## Troubleshooting

### Changing the Source Repository Branch

Attempting to change the branch being deployed from either the API or web
application repositories results in an error like:

```
module.deployment.module.api_pipeline_source_hook.aws_codepipeline_webhook.this: Modifying... [id=<example>]                                        
                                                                                                                                                                                                              
Error: doesn't support update                                                                                                                                                                                 
                                                                                                                                                                                                              
  on deployment/codepipeline-github-webhook/main.tf line 1, in resource "aws_codepipeline_webhook" "this":                                                                                                    
   1: resource "aws_codepipeline_webhook" "this" {
```

To resolve this, simply delete the offending hook:

```
terraform destroy -target module.deployment.module.api_pipeline_source_hook.aws_codepipeline_webhook.this
```

Now we can provision the infrastructure again, pointing to the desired source
branches. Note that you may have to manually trigger a CodePipeline build if the
source branches are not pushed to after the environment is re-provisioned. It
appears that
[this GitHub issue](https://github.com/terraform-providers/terraform-provider-aws/issues/8017)
may be related.

## Migrations Involving the Database or Media Files

The only part of our infrastructure that requires special care to replace is our
database and the S3 bucket storing user-uploaded files.

There are a few approaches we can take here:

* Remove the old instances from Terraform's control, have it plan the new
  instances, then migrate the data. This is the approach documented below.
* Add new Terraform resources for the new instances, provision the new
  instances, migrate, then remove the old resources. This is probably the better
  solution because it ensures we don't forget to remove old resources.

In order to migrate these services, the first step is to stop all processes that
have the ability to update data in these locations. This includes web servers,
background jobs, deployment processes, etc.

An example of how to migrate the current infrastructure is given below and
involves stopping the ECS service that provides our API web servers.

```
terraform plan -out tfplan -destroy -target module.api_cluster.aws_ecs_service.api
terraform apply tfplan
```

*__Note:__ The deployment process for the API should also be stopped because it
touches the database.*

### DB Migration

---

*__Note:__ The database is no longer exposed to the public by default. In order
to access it, we must first make it publicly accessible and add a security group
rule that allows us access.*

---

The first step is to remove the database from the Terraform state file. This
prevents Terraform from deleting it until we have finished the migration and are
sure that we have all the data.

#### State Removal

```
terraform state rm aws_db_instance.database
```

Terraform no longer knows about the database and will create a new database
instance the next time it is run.

#### Backup

To backup the old database, run the following:

```
pg_dump -d appdb -h $HOSTNAME -U $USER > dump.sql
```

Credentials can be obtained from Terraform:

```
terraform output database_user
terraform output database_password
```

#### Create New Database

At this point, we have to create the new database using Terraform. We also
update the auto-generated password for the application database user so that we
can create the user role in the next step.

```
terraform plan -out tfplan -target aws_db_instance.database -target random_string.db_password
terraform apply tfplan
```

#### Create Role

Before we can restore the database, we have to create the app database user.
First, obtain the admin credentials using:

```
terraform output database_admin_user
terraform output database_admin_password
```

Then log in as the admin user.

```
psql -h $HOSTNAME -d appdb -U $ADMIN_USER
```

Execute the following statement:

```
CREATE ROLE app_db_user WITH LOGIN PASSWORD '$PASSWORD';
```

The credentials to use here can again be pulled from Terraform:

```
terraform output database_user
terraform output database_password
```

#### Restore Data

We can now connect as the app database user and restore the backup.

```
psql -h $HOSTNAME -d appdb -U $USER < dump.sql
```

#### Delete Old Database

Once we are satisfied that the migration was successful, we can delete the old
RDS instance manually through the AWS Console, CLI, etc.

### S3 Migration

#### Terraform State Removal

The first step is to remove the S3 bucket from the Terraform state file. Before
removing it, take note of the bucket name since it will be used later.

```
terraform state rm aws_s3_bucket.static
```

This prevents Terraform from deleting the S3 bucket until we have copied over
the information.

#### Create New Bucket

We can now create the new bucket with Terraform. Take note of the new bucket
name given in the plan file.

```
terraform plan -out tfplan -target aws_s3_bucket.static
terraform apply tfplan
```

#### Copy Over Files

To copy over the existing files, use the following command:

```
aws s3 sync --region $REGION s3://$OLD_BUCKET s3://$NEW_BUCKET
```

#### Delete Old Bucket

Once we are satisfied that the migration was successful, we can manually delete
the old S3 bucket using the AWS Console, CLI, etc.


## License

This project is licensed under the [MIT License](LICENSE).


[codedeploy-ecs-hooks]: https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html#appspec-hooks-ecs
[ecs-database-migrations]: https://engineering.instawork.com/elegant-database-migrations-on-ecs-74f3487da99f
[know-me-api]: https://github.com/knowmetools/km-api
[know-me-web-app]: https://github.com/knowmetools/km-web
[lambda-migration]: scripts/api-lambda-tasks/migration_handler.py
[terraform]: https://www.terraform.io/
[terraform-download]: https://www.terraform.io/downloads.html
