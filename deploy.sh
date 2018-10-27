#!/bin/bash

set -euf
set -o pipefail

usage() {
    echo
    echo "Usage: deploy.sh <terraform-dir> <terraform-workspace> <ansible-dir>"
    echo
    echo "terraform-dir       - The path to the directory containing the project's Terraform configuration."
    echo "terraform-workspace - The name of the Terraform workspace to use."
    echo "ansible-dir         - The path to the directory containing the project's Ansible configuration."
    echo
}

###################
# Parse Arguments #
###################

if [ -z ${1+x} ]
then
    echo "No Terraform directory specified."
    usage

    exit 1
fi

TF_DIR=$1
shift

if [ -z ${1+x} ]
then
    echo "No Terraform workspace provided."
    usage

    exit 1
fi

# We export this so any Terraform commands will use the appropriate workspace.
export TF_WORKSPACE=$1
shift

if [ -z ${1+x} ]
then
    echo "No Ansible directory specified."
    usage

    exit 1
fi

ANSIBLE_DIR=$1
shift

###########################################
# Provision Infrastructure with Terraform #
###########################################

# Initialize Terraform
echo "Initializing Terraform..."
(cd ${TF_DIR}; terraform init)
echo "Done."
echo

# Build infrastructure
echo "Provisioning Infrastructure..."
echo
(cd ${TF_DIR}; terraform apply -auto-approve)
echo
echo "Done."
echo

echo "Obtaining Terraform outputs..."
TERRAFORM_OUTPUTS=$(cd ${TF_DIR}; terraform output -json)
echo "Done."

echo "Parsing data from Terraform oututs..."
#ADMIN_PASSWORD=$(cd ${TF_DIR}; terraform output admin_password)
#DB_PASSWORD=$(cd ${TF_DIR}; terraform output db_password)
#SECRET_KEY=$(cd ${TF_DIR}; terraform output secret_key)
#SERVER_HOSTNAME=$(cd ${TF_DIR}; terraform output hostname)
WEBSERVER_DOMAIN=$(echo ${TERRAFORM_OUTPUTS} | jq --raw-output .webserver_domain.value)
echo "Done."
echo

echo "Deployment Parameters:"
#echo "    Admin Password: <sensitive>"
#echo "    Database Password: <sensitive>"
#echo "    Domain Name: ${SERVER_HOSTNAME}"
#echo "    Secret Key: <sensitive>"
echo "    Webserver Domain: ${WEBSERVER_DOMAIN}"
echo

##############################
# Generate Ansible Inventory #
##############################

# Generate a temporary directory to store files in
tmpdir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")
inventory_file="${tmpdir}/inventory"

cat > ${inventory_file} <<EOF
[webservers]
${WEBSERVER_DOMAIN}
EOF

echo "Generated inventory file:"
echo
cat ${inventory_file}
echo

#####################################
# Configure Webservers with Ansible #
#####################################

(
    cd ${ANSIBLE_DIR}

    ansible-playbook \
        --inventory ${inventory_file} \
        deploy.yml
)
