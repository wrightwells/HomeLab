#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"
DEFAULT_VAULT_FILE="$HOME/.config/ansible/homelab-vault-pass.txt"
DEFAULT_TERRAFORM_VARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
GENERATED_TERRAFORM_VARS_DIR="$TERRAFORM_DIR/generated"
PROXMOX_HOST_CONTROL_TFVARS_FILE="$GENERATED_TERRAFORM_VARS_DIR/proxmox-host-control.auto.tfvars.json"

ensure_vault_file() {
  if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    return 0
  fi

  if [[ -f "$DEFAULT_VAULT_FILE" ]]; then
    export ANSIBLE_VAULT_PASSWORD_FILE="$DEFAULT_VAULT_FILE"
    return 0
  fi

  cat >&2 <<EOF
Ansible vault password file not found.
Set ANSIBLE_VAULT_PASSWORD_FILE or create:
  $DEFAULT_VAULT_FILE
EOF
  return 1
}

setup_ansible_env() {
  export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-/tmp/ansible-local}"
  export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/ansible-remote}"

  if [[ -z "${HOMELAB_SSH_PRIVATE_KEY_FILE:-}" ]]; then
    if [[ -f "$HOME/.ssh/homelab-bootstrap" ]]; then
      export HOMELAB_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/homelab-bootstrap"
    else
      export HOMELAB_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/id_ed25519"
    fi
  fi
}

terraform_var_file_args() {
  local -a args
  args=("-var-file=$DEFAULT_TERRAFORM_VARS_FILE")

  if [[ -f "$PROXMOX_HOST_CONTROL_TFVARS_FILE" ]]; then
    args+=("-var-file=$PROXMOX_HOST_CONTROL_TFVARS_FILE")
  fi

  printf '%s\n' "${args[@]}"
}

terraform_env_dir() {
  local env_name="${1:-root}"

  case "$env_name" in
    root)
      printf '%s\n' "$TERRAFORM_DIR"
      ;;
    pfsense|production)
      printf '%s\n' "$TERRAFORM_DIR/environments/$env_name"
      ;;
    *)
      cat >&2 <<EOF
Unknown Terraform environment: $env_name
Expected one of: root, pfsense, production
EOF
      return 1
      ;;
  esac
}
