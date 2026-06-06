#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

LOG_DIR="${LOG_DIR:-/mnt/appdata/homelab-control/bin}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/ansible.log}"

mkdir -p "$LOG_DIR"
mkdir -p "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP"

cd "$ANSIBLE_DIR"
ansible-playbook \
  -i inventories/production/hosts.ini \
  -e "ansible_ssh_private_key_file=$HOMELAB_SSH_PRIVATE_KEY_FILE" \
  --private-key "$HOMELAB_SSH_PRIVATE_KEY_FILE" \
  playbooks/site.yml \
  "$@" 2>&1 | tee "$LOG_FILE"
