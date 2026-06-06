#!/usr/bin/env bash
# verify-ansible-hosts.sh -- Step 10.1: Verify Ansible can reach all hosts.
#
# Pings all hosts in the production inventory and reports reachability.
# Expects the vault password file at ~/.config/ansible/homelab-vault-pass.txt
#
# Usage: ./scripts/verify-ansible-hosts.sh

set -euo pipefail

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env
mkdir -p "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP"

echo "=== Verifying Ansible host reachability ==="
cd "$ANSIBLE_DIR"
ansible all \
  -i inventories/production/hosts.ini \
  -m ping \
  -e "ansible_ssh_private_key_file=$HOMELAB_SSH_PRIVATE_KEY_FILE" \
  --private-key "$HOMELAB_SSH_PRIVATE_KEY_FILE"

echo ""
echo "=== Host verification complete ==="
echo "If any host shows UNREACHABLE, check:"
echo "  - The host is running (qm status VMID or pct status CTID)"
echo "  - Network connectivity from the Proxmox host (guest VLANs may not be routable from your workstation yet)"
echo "  - SSH keys / passwords are correct"
