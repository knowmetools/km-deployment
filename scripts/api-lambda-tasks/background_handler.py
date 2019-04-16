"""
An AWS Lambda function used to run periodic background jobs on ECS.

The complication with running these tasks is that we need to run them on
the same version of the Docker image that the web servers are currently
running on.
"""

import logging

import boto3

from utils import env_list, env_param


# Logging setup is done by Lambda
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Initialize clients for the required services.
ecs = boto3.client('ecs')


def handler(event, context):
    """
    The entry point into the lambda function.

    This function finds the version of the Docker image running a
    specific service on a specific ECS cluster and then launches a new
    task on the same ECS cluster running an overridden version of the
    same Docker image.

    Args:
        event:
            A dictionary containing information provided when the
            function was invoked.
        context:
            An unknown object containing additional context for the
            request.

    Returns:
        A dictionary containing a response code and status message.
    """
    # The name of the ECS cluster running the existing API task.
    cluster = env_param('CLUSTER')
    # The name of the service running on the cluster whose image should
    # be used to run the background jobs.
    service = env_param('SERVICE')
    # The name of the container within the service to override.
    container_name = env_param('CONTAINER_NAME')

    # A list of security group IDs that the migration task should be
    # placed in.
    security_groups = env_list('SECURITY_GROUPS')

    # A list of subnet IDs corresponding to the subnets the migration
    # task may be placed in.
    subnet_ids = env_list('SUBNETS')

    logger.info('Beginning process of running background tasks.')
    logger.info(
        'Searching cluster "%s" for "%s" service...',
        cluster,
        service,
    )
    logger.info(
        'Task to be executed with security groups %s in subnets %s',
        security_groups,
        subnet_ids,
    )

    # The first step is to describe the service so we can get access to
    # the task definition being used.
    services_info = ecs.describe_services(cluster=cluster, services=[service])

    assert len(services_info['services']) == 1, (
        'Received multiple services. Aborting!'
    )

    logger.info('Received information about "%s" service.', service)

    service_info = services_info['services'][0]
    task_definition_arn = service_info['taskDefinition']

    logger.info(
        'ARN of task definition from service is %s',
        task_definition_arn,
    )

    # Pull roles from task definition information. We run the background
    # task with the same roles that the API web server tasks normally
    # run under.
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
                    'command': ['background-jobs'],
                    'name': container_name,
                },
            ],
            # The role used by the ECS agent.
            'executionRoleArn': execution_role,
            # The role our code runs under.
            'taskRoleArn': task_role,
        },
        networkConfiguration={
            'awsvpcConfiguration': {
                # Need to assign a public IP so the image can be pulled.
                'assignPublicIp': 'ENABLED',
                'securityGroups': security_groups,
                'subnets': subnet_ids,
            },
        },
        taskDefinition=task_definition_arn,
    )

    return {
        'body': 'Success',
        'statusCode': 200
    }
