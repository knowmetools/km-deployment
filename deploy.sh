#!/bin/bash

set -euf
set -o pipefail

usage() {
    echo
    echo "Usage: deploy.sh <deploy-dir> <terraform-workspace>"
    echo
    echo "deploy-dir          - The path to the directory containing the deployment configuration."
    echo "terraform-workspace - The name of the Terraform workspace to use."
    echo
}

###################
# Parse Arguments #
###################

if [[ -z ${1+x} ]]
then
    echo "No deploy directory specified."
    usage

    exit 1
fi

DEPLOY_DIR=$1
shift

if [[ -z ${1+x} ]]
then
    echo "No Terraform workspace provided."
    usage

    exit 1
fi

# We export this so any Terraform commands will use the appropriate workspace.
export TF_WORKSPACE=$1
shift

TF_DB_DIR=${DEPLOY_DIR}/terraform/database
TF_INFRA_DIR=${DEPLOY_DIR}/terraform/infrastructure

###########################################
# Provision Infrastructure with Terraform #
###########################################

# Initialize Terraform
echo "Initializing Terraform for infrastructure..."
(cd ${TF_INFRA_DIR}; terraform init)
echo "Done."
echo

# Build infrastructure
echo "Provisioning Infrastructure..."
echo
(cd ${TF_INFRA_DIR}; terraform apply -auto-approve)
echo
echo "Done."
echo

#####################################
# Provision Database with Terraform #
#####################################

# Initialize Terraform
echo "Initializing Terraform for database..."
(cd ${TF_DB_DIR}; terraform init)
echo "Done."
echo

# Build infrastructure
echo "Provisioning database..."
echo
(cd ${TF_DB_DIR}; terraform apply -auto-approve)
echo
echo "Done."
echo
