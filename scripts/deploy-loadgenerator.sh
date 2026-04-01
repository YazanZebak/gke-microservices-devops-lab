#!/bin/bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${REPO_ROOT}/infrastructure/terraform"
ANSIBLE_DIR="${REPO_ROOT}/infrastructure/ansible/loadgenerator"

# Provision VM with Terraform
echo "Provisioning load generator VM..."
cd "${TERRAFORM_DIR}"
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configure VM with Ansible
echo "Configuring load generator VM..."
ansible-playbook -i "${ANSIBLE_DIR}/inventory.ini" "${ANSIBLE_DIR}/playbook.yml"

echo "Load generator deployed."
VM_IP=$(terraform -chdir="${TERRAFORM_DIR}" output -raw load_generator_ip)
echo "Load generator deployed at ${VM_IP}"
echo "Verify with: ssh -i ~/.ssh/google_compute_engine debian@${VM_IP} 'sudo docker logs locust'"