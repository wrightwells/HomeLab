#!/usr/bin/env bash
# verify-ansible-hosts.sh -- Step 10.1: Verify Ansible can reach all hosts.
#
# Pings all hosts in the production inventory and reports reachability.
# Expects the vault password file at ~/.config/ansible/homelab-vault-pass.txt
#
# Usage: ./scripts/verify-ansible-hosts.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$ROOT_DIR/ansible"
VAULT_FILE="$HOME/.config/ansible/homelab-vault-pass.txt"

if [ ! -f "$VAULT_FILE" ]; then
  echo "ERROR: Vault password file not found at $VAULT_FILE" >&2
  exit 1
fi

export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_FILE"

echo "=== Verifying Ansible host reachability ==="
cd "$ANSIBLE_DIR"
ansible all -m ping

echo ""
echo "=== Host verification complete ==="
echo "If any host shows UNREACHABLE, check:"
echo "  - The host is running (qm status VMID or pct status CTID)"
echo "  - Network connectivity (ping from Proxmox host)"
echo "  - SSH keys / passwords are correct"
