#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SEARCH_ROOT="$ANSIBLE_DIR/files/compose"
SOURCE_PASSWORD=""
TARGET_PASSWORD=""
TMP_DIR=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --source-password <password> --target-password <password> [--search-root <dir>]

What it does:
  - searches the Ansible compose tree for stack.env.vault and stack.env files
  - decrypts each stack.env.vault to stack.env using the source password
  - re-encrypts each stack.env to stack.env.vault using the target password
  - leaves the plain stack.env files on disk

Default search root:
  $SEARCH_ROOT
EOF
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-password)
      SOURCE_PASSWORD="${2:-}"
      shift 2
      ;;
    --target-password)
      TARGET_PASSWORD="${2:-}"
      shift 2
      ;;
    --search-root)
      SEARCH_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE_PASSWORD" || -z "$TARGET_PASSWORD" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$SEARCH_ROOT" ]]; then
  echo "Search root does not exist: $SEARCH_ROOT" >&2
  exit 1
fi

if ! command -v ansible-vault >/dev/null 2>&1; then
  echo "ansible-vault is required but was not found in PATH." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
SOURCE_PASSWORD_FILE="$TMP_DIR/source-password.txt"
TARGET_PASSWORD_FILE="$TMP_DIR/target-password.txt"
printf '%s\n' "$SOURCE_PASSWORD" > "$SOURCE_PASSWORD_FILE"
printf '%s\n' "$TARGET_PASSWORD" > "$TARGET_PASSWORD_FILE"
chmod 600 "$SOURCE_PASSWORD_FILE" "$TARGET_PASSWORD_FILE"

mapfile -d '' VAULT_FILES < <(find "$SEARCH_ROOT" -type f -name 'stack.env.vault' -print0 | sort -z)
mapfile -d '' PLAIN_FILES < <(find "$SEARCH_ROOT" -type f -name 'stack.env' -print0 | sort -z)

decrypt_count=0
encrypt_count=0

for vault_path in "${VAULT_FILES[@]}"; do
  [[ -n "$vault_path" ]] || continue

  plain_path="${vault_path%.vault}"

  echo "Decrypting: $vault_path -> $plain_path"
  ansible-vault view --vault-password-file "$SOURCE_PASSWORD_FILE" "$vault_path" > "$plain_path"
  chmod 600 "$plain_path"
  decrypt_count=$((decrypt_count + 1))
done

# Re-scan after decryption so newly written stack.env files are included.
mapfile -d '' PLAIN_FILES < <(find "$SEARCH_ROOT" -type f -name 'stack.env' -print0 | sort -z)

for plain_path in "${PLAIN_FILES[@]}"; do
  [[ -n "$plain_path" ]] || continue

  vault_path="${plain_path}.vault"

  echo "Encrypting: $plain_path -> $vault_path"
  ansible-vault encrypt \
    --output "$vault_path" \
    --vault-password-file "$TARGET_PASSWORD_FILE" \
    "$plain_path"
  chmod 600 "$vault_path"
  encrypt_count=$((encrypt_count + 1))
done

echo
echo "Completed."
echo "Decrypted vault files: $decrypt_count"
echo "Encrypted plain files: $encrypt_count"
echo "Search root: $SEARCH_ROOT"
