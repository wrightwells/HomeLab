#!/usr/bin/env bash
# apply-pfsense-config.sh -- Step 10.3: Apply pfSense configuration via Ansible.
#
# Runs the dedicated pfSense playbook. Requires pfSense to be installed,
# configured, and reachable at 10.10.99.1 (management VLAN).
#
# Usage: ./scripts/apply-pfsense-config.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$ROOT_DIR/ansible"
VAULT_FILE="$HOME/.config/ansible/homelab-vault-pass.txt"

if [ ! -f "$VAULT_FILE" ]; then
  echo "ERROR: Vault password file not found at $VAULT_FILE" >&2
  exit 1
fi

export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_FILE"

echo "=== Applying pfSense configuration ==="
cd "$ANSIBLE_DIR"
ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml

echo ""
echo "=== pfSense configuration applied ==="
