#!/usr/bin/env bash

# setup-lxc-root-password.sh
#
# Run this BEFORE Terraform creates your LXCs (bootstrap step 7.4).
#
# This script:
#   1. Prompts for the Ansible vault password (the plain-text secret used for
#      all Ansible Vault operations in this repo).
#   2. Derives a SHA-512 hash from that same secret.
#   3. Writes the hash encrypted with Ansible Vault to the LXC root passwords
#      file.
#   4. Sets lxc_root_password in terraform/terraform.tfvars so Terraform creates
#      LXCs with the correct initial password.
#   5. Saves the vault password to ~/.config/ansible/homelab-vault-pass.txt.
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
  - Terraform will use this value to create LXCs with the correct password.

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
echo "Encrypting and writing vault file to: ${VAULT_FILE#${REPO_ROOT}/}"

mkdir -p "$(dirname "$VAULT_FILE")"

echo "$hash" | \
  ansible-vault encrypt_string --stdin-name 'lxc_root_password_hash' \
  > "$VAULT_FILE" \
  <<< "$vault_password"

if [[ $? -ne 0 ]]; then
  echo "Error: failed to encrypt vault file." >&2
  exit 1
fi

echo "Vault file written successfully."

# Set lxc_root_password in terraform/terraform.tfvars
TFVARS="${REPO_ROOT}/terraform/terraform.tfvars"
if [[ -f "$TFVARS" ]]; then
  if grep -q '^lxc_root_password' "$TFVARS" 2>/dev/null; then
    sed -i "s|^lxc_root_password.*|lxc_root_password = \"${vault_password}\"|" "$TFVARS"
    echo "Updated lxc_root_password in terraform/terraform.tfvars."
  else
    echo "" >> "$TFVARS"
    echo "lxc_root_password = \"${vault_password}\"" >> "$TFVARS"
    echo "Appended lxc_root_password to terraform/terraform.tfvars."
  fi
else
  echo "WARNING: terraform/terraform.tfvars not found. Add this line manually:"
  echo "  lxc_root_password = \"${vault_password}\""
fi

# Save vault password file
VAULT_PASS_FILE="${HOME}/.config/ansible/homelab-vault-pass.txt"
mkdir -p "$(dirname "$VAULT_PASS_FILE")"
printf '%s\n' "$vault_password" > "$VAULT_PASS_FILE"
chmod 600 "$VAULT_PASS_FILE"
echo "Vault password file saved to ${VAULT_PASS_FILE}."

echo
echo "Step 7.4 complete."
echo
echo "After Terraform and proxmox-apply-lxc-postcreate.sh have run, apply"
echo "the password to the rebooted LXCs with:"
echo
echo "  ./scripts/apply-lxc-root-password.sh"
