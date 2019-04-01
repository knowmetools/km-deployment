import logging
import os
import re

import boto3

TASK_DEFINITION_PATTERN = r'TaskDefinition: (\S+)$'

# Logging setup is done by Lambda
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

codedeploy = boto3.client('codedeploy')
ecs = boto3.client('ecs')


def handler(event, context):
    cluster = os.getenv('CLUSTER')
    container_name = os.getenv('CONTAINER_NAME')

    security_group_str = os.getenv('SECURITY_GROUPS', '')
    security_groups = security_group_str.split(',') if security_group_str else []

    subnet_ids_str = os.getenv('SUBNETS', '')
    subnet_ids = subnet_ids_str.split(',') if subnet_ids_str else []

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

    ecs.run_task(
        cluster=cluster,
        launchType='FARGATE',
        overrides={
            'containerOverrides': [
                {
                    'command': ['migrate'],
                    'name': container_name,
                },
            ],
        },
        networkConfiguration = {
            'awsvpcConfiguration': {
                # Need to assign a public IP so the container can be
                # pulled.
                'assignPublicIp': 'ENABLED',
                'securityGroups': security_groups,
                'subnets': subnet_ids,
            },
        },
        taskDefinition=task_definition_arn,
    )

    codedeploy.put_lifecycle_event_hook_execution_status(
        deploymentId=deployment_id,
        lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
        status='Succeeded',
    )

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
