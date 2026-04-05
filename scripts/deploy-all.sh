#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

"$ROOT_DIR/scripts/terraform-init.sh" pfsense
(cd "$TERRAFORM_DIR/environments/pfsense" && terraform validate)
"$ROOT_DIR/scripts/terraform-apply.sh" pfsense
"$ROOT_DIR/scripts/terraform-init.sh" production
(cd "$TERRAFORM_DIR/environments/production" && terraform validate)
"$ROOT_DIR/scripts/terraform-apply.sh" production
(cd "$ANSIBLE_DIR" && ansible-galaxy collection install -r requirements.yml)
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --syntax-check)
(cd "$ANSIBLE_DIR" && ansible all -m ping)
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml)
