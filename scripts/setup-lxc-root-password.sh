#!/usr/bin/env bash

# setup-lxc-root-password.sh
#
# Generates the LXC root password vault file for step 7.4 of the bootstrap guide.
#
# This script:
#   1. Prompts for the Ansible vault password (the plain-text secret used for
#      all Ansible Vault operations in this repo).
#   2. Derives a SHA-512 hash from that same secret.
#   3. Writes the hash encrypted with Ansible Vault to the LXC root passwords
#      file, so the lxc-root-password.yml playbook can set it on all LXCs.
#   4. Reminds you to set lxc_root_password in terraform.tfvars to match.
#
# Usage:
#   ./scripts/setup-lxc-root-password.sh
#
# The same plain-text password you enter here is:
#   - the initial root password for all LXC containers
#   - your Ansible vault password for this repo
#   - the value for lxc_root_password in terraform.tfvars

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAULT_FILE="${REPO_ROOT}/ansible/inventories/production/group_vars/lxc_root_passwords.vault.yml"

cat <<'EOF'
LXC Root Password Setup (Bootstrap Step 7.4)

The LXC root password uses the same plain-text secret as the Ansible vault
password. This means:
  - The password you enter here is the initial root password for all LXCs.
  - The same password is used for Ansible Vault operations.
  - Set lxc_root_password in terraform.tfvars to this same value.

EOF

# Prompt for the vault password (hidden input)
read -r -s -p "Enter vault password (used as LXC root password): " vault_password
echo

if [[ -z "$vault_password" ]]; then
  echo "Error: password cannot be empty." >&2
  exit 1
fi

# Confirm
read -r -s -p "Confirm vault password: " vault_password_confirm
echo

if [[ "$vault_password" != "$vault_password_confirm" ]]; then
  echo "Error: passwords do not match." >&2
  exit 1
fi

echo
echo "Generating SHA-512 hash from vault password..."

# Generate SHA-512 hash using openssl
hash=$(openssl passwd -6 "$vault_password")
if [[ -z "$hash" ]]; then
  echo "Error: failed to generate password hash." >&2
  exit 1
fi

echo "Hash generated successfully."

# Write the vault file using ansible-vault encrypt_string
# The output format is: lxc_root_password_hash: !vault | ...
echo "Encrypting and writing vault file to: ${VAULT_FILE#${REPO_ROOT}/}"

mkdir -p "$(dirname "$VAULT_FILE")"

echo "$hash" | \
  ansible-vault encrypt_string --stdin-name 'lxc_root_password_hash' \
  > "$VAULT_FILE" \
  <<< "$vault_password"

if [[ $? -eq 0 ]]; then
  echo
  echo "Vault file written successfully."
  echo
  echo "Next steps:"
  echo "  1. Set lxc_root_password in terraform/terraform.tfvars to the"
  echo "     same plain-text vault password you entered above."
  echo "  2. After creating LXCs via Terraform, the initial root password"
  echo "     for all LXC containers is the vault password you entered."
  echo "  3. To apply the password to existing LXCs, run:"
  echo "       cd ansible"
  echo "       ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt \\"
  echo "         ansible-playbook -i inventories/production/hosts.ini playbooks/lxc-root-password.yml"
  echo
  echo "  4. Also save the vault password to ~/.config/ansible/homelab-vault-pass.txt:"
  echo "       mkdir -p ~/.config/ansible"
  echo "       printf '%s\n' '<your-password>' > ~/.config/ansible/homelab-vault-pass.txt"
  echo "       chmod 600 ~/.config/ansible/homelab-vault-pass.txt"
else
  echo "Error: failed to encrypt vault file." >&2
  exit 1
fi
