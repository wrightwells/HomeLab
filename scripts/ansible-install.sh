#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

cd "$ANSIBLE_DIR"
ansible-galaxy collection install -r requirements.yml
