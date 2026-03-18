#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

(cd "$TERRAFORM_DIR" && terraform init)
(cd "$TERRAFORM_DIR" && terraform validate)
(cd "$TERRAFORM_DIR" && terraform apply)
(cd "$ANSIBLE_DIR" && ansible-galaxy collection install -r requirements.yml)
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --syntax-check)
(cd "$ANSIBLE_DIR" && ansible all -m ping)
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml)
