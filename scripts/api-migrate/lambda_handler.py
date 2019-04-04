"""
An AWS Lambda function used to launch a migration task on ECS.

At some point before running a new version of our application's codebase
we need to perform various migration tasks such as migrating the
database or collecting static files. These tasks are performed in a
one-off task that is called prior to routing traffic to a new deployed
version of our ECS application.
"""

import logging
import os
import re

import boto3


# The regular expression used to pull a task definition out of the
# contents of an 'appspec.yaml' file.
TASK_DEFINITION_PATTERN = r'TaskDefinition: (\S+)$'

# Logging setup is done by Lambda
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Initialize clients for the required services.
codedeploy = boto3.client('codedeploy')
ecs = boto3.client('ecs')
ssm = boto3.client('ssm')


def handler(event, context):
    """
    The entry point into the lambda function.

    The main purpose of the function is to back track up the deployment
    "call stack" to find which specific image to use for the migration
    task. It is important that the image used for the migration task and
    the image being deployed to serve the API are the same because the
    images are essentially versions of the codebase.

    The chain we have to follow looks something like:

        Deployment ID > Application Revision > Task Definition

    The task definition contains the information we actually need to
    launch the migration task.

    Args:
        event:
            A dictionary containing information about the deployment
            from CodeDeploy that invoked the hook.
        context:
            An unknown object containing additional context for the
            request.

    Returns:
        A dictionary containing a response code and status message.
    """
    # Which cluster to launch the migration task on.
    cluster = os.getenv('CLUSTER')
    # The name of the API webserver container being overridden to run
    # the migration task.
    container_name = os.getenv('CONTAINER_NAME')

    # A comma-separated list of security group IDs that the migration
    # task should be placed in.
    security_group_str = os.getenv('SECURITY_GROUPS', '')
    security_groups = security_group_str.split(',') if security_group_str else []

    # A comma-separated list of subnet IDs corresponding to the subnets
    # the migration task may be placed in.
    subnet_ids_str = os.getenv('SUBNETS', '')
    subnet_ids = subnet_ids_str.split(',') if subnet_ids_str else []

    # Admin credentials. Passwords are pulled from SSM.
    admin_email = os.getenv('ADMIN_EMAIL')
    admin_password_ssm_name = os.getenv('ADMIN_PASSWORD_SSM_NAME')
    database_admin_password_ssm_name = os.getenv(
        'DATABASE_ADMIN_PASSWORD_SSM_NAME'
    )
    database_admin_user = os.getenv('DATABASE_ADMIN_USER')

    # The deployment ID and execution ID are used to pull further
    # information and report statuses.
    deployment_id = event['DeploymentId']
    lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']

    logger.info('Received event for deployment %s', deployment_id)
    logger.info(
        'Will execute task on cluster %s for container %s',
        cluster,
        container_name,
    )
    logger.info(
        'Task to be executed with security groups %s in subnets %s',
        security_groups,
        subnet_ids,
    )

    # The first step towards getting to the task definition is to
    # retrieve the application revision that the current deployment is
    # deploying.
    application, revision_hash = get_app_info(deployment_id)
    logger.info(
        'Current deployment is for application with revision hash %s',
        revision_hash,
    )

    app_revision = codedeploy.get_application_revision(
        applicationName=application,
        revision={
            'revisionType': 'String',
            'string': {
                'sha256': revision_hash,
            },
        }
    )

    # Once we have the information about the specific application
    # revision being deployed, we can parse out the task definition ARN
    # that was automatically injected by CodeDeploy.
    appspec_content = app_revision['revision']['string']['content']
    task_definition_arn = re.search(
        TASK_DEFINITION_PATTERN,
        appspec_content,
        re.M,
    ).group(1)

    logger.info(
        'ARN of task definition from deployment is %s',
        task_definition_arn,
    )

    # Pull roles from task definition information. We run the migration
    # task with the same roles that the API webserver tasks normally run
    # under.
    task_definition = ecs.describe_task_definition(
        taskDefinition=task_definition_arn,
    )
    execution_role = task_definition['taskDefinition']['executionRoleArn']
    task_role = task_definition['taskDefinition']['taskRoleArn']
    logger.info(
        'Will execute task with role %s as role %s',
        task_role,
        execution_role,
    )

    # Pull admin passwords from SSM
    admin_password = get_secure_parameter(admin_password_ssm_name)
    database_admin_password = get_secure_parameter(
        database_admin_password_ssm_name
    )

    # Using the parameters we have pulled from the previous steps, we
    # launch what is essentially a modified version of the webserver
    # task that performs the tasks required to migrate between versions
    # of the codebase.
    ecs.run_task(
        cluster=cluster,
        launchType='FARGATE',
        overrides={
            'containerOverrides': [
                {
                    'command': ['migrate'],
                    # Insert admin credentials as env vars.
                    'environment': [
                        {
                            'name': 'ADMIN_EMAIL',
                            'value': admin_email,
                        },
                        {
                            'name': 'ADMIN_PASSWORD',
                            'value': admin_password,
                        },
                        {
                            'name': 'DATABASE_ADMIN_PASSWORD',
                            'value': database_admin_password,
                        },
                        {
                            'name': 'DATABASE_ADMIN_USER',
                            'value': database_admin_user,
                        },
                    ],
                    'name': container_name,
                },
            ],
            # The role used by the ECS agent.
            'executionRoleArn': execution_role,
            # The role our code runs under.
            'taskRoleArn': task_role,
        },
        networkConfiguration = {
            'awsvpcConfiguration': {
                # Need to assign a public IP so the image can be pulled.
                'assignPublicIp': 'ENABLED',
                'securityGroups': security_groups,
                'subnets': subnet_ids,
            },
        },
        taskDefinition=task_definition_arn,
    )

    # For now we assume that successfully submitting the 'run_task' call
    # means the migration is successful. This is NOT actually the case
    # because the task runs asynchronously so we would have to continue
    # to poll to get a success code.
    codedeploy.put_lifecycle_event_hook_execution_status(
        deploymentId=deployment_id,
        lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
        status='Succeeded',
    )

    # CodeDeploy will keep trying the hook if it does not receive a 200
    # response.
    return {
        'body': 'Success',
        'statusCode': 200
    }


def get_app_info(deployment_id):
    """
    Get information about a specific application revision that is being
    deployed.

    Args:
        deployment_id:
            The ID of the deployment to retrieve application info for.

    Returns:
        A tuple whose elements are the name of the application that the
        deployment is for and the SHA256 hash identifying the revision
        being deployed.
    """
    logger.debug(
        'Fetching deployment info for deployment with ID %s',
        deployment_id,
    )

    deployment = codedeploy.get_deployment(deploymentId=deployment_id)

    logger.debug('Received deployment info: %s', deployment)

    info = deployment['deploymentInfo']
    application = info['applicationName']
    revision_hash = info['revision']['string']['sha256']

    return application, revision_hash


def get_secure_parameter(parameter_name):
    """
    Get a parameter of type 'SecureString' from SSM.

    Args:
        parameter_name:
            The name of the parameter to retrieve.

    Returns:
        The plaintext value of the parameter.
    """
    param_info = ssm.get_parameter(
        Name=parameter_name,
        WithDecryption=True,
    )

    return param_info['Parameter']['Value']
