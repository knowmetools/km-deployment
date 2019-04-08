# Know Me Deployment

Deployment process for the entire Know Me app ecosystem. Infrastructure is
managed with [Terraform][terraform].

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

*__Note:__ The database is no longer exposed to the public by default. In order
to access it, we must first make it publicly accessible and add a security group
rule that allows us access.*

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


[know-me-api]: https://github.com/knowmetools/km-api
[know-me-web-app]: https://github.com/knowmetools/km-web
[terraform]: https://www.terraform.io/
[terraform-download]: https://www.terraform.io/downloads.html
