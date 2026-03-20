#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

cd "$ANSIBLE_DIR"
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/production/hosts.ini playbooks/check.yml --syntax-check
ansible all -m ping

if [[ "${SEMAPHORE_RUN_ANSIBLE_CHECK_MODE:-false}" == "true" ]]; then
  ansible-playbook -i inventories/production/hosts.ini playbooks/check.yml --check --diff
fi
