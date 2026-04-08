#!/usr/bin/env bash
# recreate-stack-vaults.sh -- Re-encrypt all stack.env.vault files from their .example counterparts
# using the current vault password.
#
# Usage: ./scripts/recreate-stack-vaults.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$ROOT_DIR/ansible"
VAULT_FILE="$HOME/.config/ansible/homelab-vault-pass.txt"

if [[ ! -f "$VAULT_FILE" ]]; then
  echo "Error: vault password file not found at $VAULT_FILE" >&2
  exit 1
fi

cd "$ANSIBLE_DIR"

count=0

# Find all stack.env.vault files and re-create them from their .example counterparts
find files -name "stack.env.vault" -print0 | while IFS= read -r -d '' vault_file; do
  dir="$(dirname "$vault_file")"
  base="$(basename "$vault_file")"
  
  # Try stack.env.example first, then stack.env.example.j2
  if [[ -f "$dir/stack.env.example" ]]; then
    src_file="$dir/stack.env.example"
  elif [[ -f "$dir/stack.env.example.j2" ]]; then
    # For .j2 files, just copy as-is (they're templates, not vaulted)
    continue
  else
    echo "Warning: no example file for $vault_file, skipping" >&2
    continue
  fi
  
  echo "Re-encrypting: $vault_file (from $src_file)"
  
  # Read the example file and encrypt it
  ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_FILE" ansible-vault encrypt \
    --output "$vault_file" \
    "$src_file"
  
  count=$((count + 1))
done

echo "Done. Re-encrypted $count vault files."
