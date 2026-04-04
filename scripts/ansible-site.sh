#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

LOG_DIR="${LOG_DIR:-/mnt/appdata/homelab-control/bin}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/ansible.log}"

mkdir -p "$LOG_DIR"

cd "$ANSIBLE_DIR"
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml "$@" 2>&1 | tee "$LOG_FILE"
