#!/usr/bin/env bash
# ensure-proxmox-host-ansible.sh -- Make the Proxmox host usable as the Ansible control node.
#
# This script runs from your workstation and installs the minimum Ansible
# tooling on the Proxmox host, then installs the repo's Ansible collections in
# the host-local HomeLab checkout.
#
# Usage:
#   ./scripts/ensure-proxmox-host-ansible.sh
#   PROXMOX_HOST=root@10.10.99.110 REMOTE_REPO_DIR=/root/HomeLab ./scripts/ensure-proxmox-host-ansible.sh

set -euo pipefail

source "$(dirname "$0")/_common.sh"

PROXMOX_HOST="${PROXMOX_HOST:-root@10.10.1.110}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-/root/HomeLab}"
REMOTE_VAULT_FILE="${REMOTE_VAULT_FILE:-/root/.config/ansible/homelab-vault-pass.txt}"
REMOTE_HOST_CONTROL_KEY="${REMOTE_HOST_CONTROL_KEY:-/root/.ssh/homelab-bootstrap}"
TEMP_VAULT_FILE=""

if ! ensure_vault_file; then
  if [[ -f "$DEFAULT_TERRAFORM_VARS_FILE" ]]; then
    vault_secret="$(sed -n 's/^lxc_root_password *= *"\(.*\)"$/\1/p' "$DEFAULT_TERRAFORM_VARS_FILE" | tail -n 1)"
    if [[ -n "$vault_secret" ]]; then
      TEMP_VAULT_FILE="$(mktemp)"
      chmod 600 "$TEMP_VAULT_FILE"
      printf '%s\n' "$vault_secret" > "$TEMP_VAULT_FILE"
      export ANSIBLE_VAULT_PASSWORD_FILE="$TEMP_VAULT_FILE"
    fi
  fi
fi

ensure_vault_file

ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "mkdir -p $(printf '%q' "$(dirname "$REMOTE_VAULT_FILE")")"
scp -q -o StrictHostKeyChecking=no "$ANSIBLE_VAULT_PASSWORD_FILE" "$PROXMOX_HOST:$REMOTE_VAULT_FILE"

ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "bash -lc '
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ansible git curl jq python3 python3-pip sshpass

if [ ! -d \"$REMOTE_REPO_DIR/.git\" ]; then
  echo \"ERROR: Expected repo checkout at $REMOTE_REPO_DIR on the Proxmox host\" >&2
  exit 1
fi

mkdir -p \"$(dirname "$REMOTE_HOST_CONTROL_KEY")\"
chmod 700 \"$(dirname "$REMOTE_HOST_CONTROL_KEY")\"
if [ ! -f \"$REMOTE_HOST_CONTROL_KEY\" ]; then
  ssh-keygen -t ed25519 -C homelab-proxmox-control -f \"$REMOTE_HOST_CONTROL_KEY\" -N \"\"
fi

host_control_public_key=\"\$(cat \"${REMOTE_HOST_CONTROL_KEY}.pub\")\"
mkdir -p \"$REMOTE_REPO_DIR/terraform/generated\"
jq -Rn --arg key \"\$host_control_public_key\" \
  '\''{host_control_ssh_public_key: $key}'\'' > \"$REMOTE_REPO_DIR/terraform/generated/proxmox-host-control.auto.tfvars.json\"

chmod 600 \"$REMOTE_VAULT_FILE\"

cd \"$REMOTE_REPO_DIR/ansible\"
ansible-galaxy collection install -r requirements.yml

ansible --version | head -1
'"

mkdir -p "$GENERATED_TERRAFORM_VARS_DIR"
host_control_public_key="$(ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "cat '${REMOTE_HOST_CONTROL_KEY}.pub'")"
jq -Rn --arg key "$host_control_public_key" \
  '{host_control_ssh_public_key: $key}' > "$PROXMOX_HOST_CONTROL_TFVARS_FILE"

if [[ -n "$TEMP_VAULT_FILE" ]]; then
  rm -f "$TEMP_VAULT_FILE"
fi
