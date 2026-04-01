#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  setup-ssh-key-login.sh [--host HOST] [--user USER] [--port PORT] [--key-file PATH] [--comment TEXT]

Defaults:
  --host      10.10.99.10
  --user      root
  --port      22
  --key-file  ~/.ssh/id_ed25519
  --comment   <user>@<hostname>

What it does:
  1. Creates an ed25519 keypair if the private key does not already exist.
  2. Copies the public key to the remote account's authorized_keys using password auth.
  3. Prints the test command and the server-side SSH settings to disable after key auth works.

Examples:
  scripts/setup-ssh-key-login.sh
  scripts/setup-ssh-key-login.sh --host 10.10.99.10 --user root
  scripts/setup-ssh-key-login.sh --host 10.10.99.10 --user ww --key-file ~/.ssh/homelab_ed25519
EOF
}

HOST="10.10.99.10"
USER_NAME="root"
PORT="22"
KEY_FILE="$HOME/.ssh/id_ed25519"
COMMENT="${USER:-$(id -un)}@$(hostname -s)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:?missing value for --host}"
      shift 2
      ;;
    --user)
      USER_NAME="${2:?missing value for --user}"
      shift 2
      ;;
    --port)
      PORT="${2:?missing value for --port}"
      shift 2
      ;;
    --key-file)
      KEY_FILE="${2:?missing value for --key-file}"
      shift 2
      ;;
    --comment)
      COMMENT="${2:?missing value for --comment}"
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

PUB_KEY_FILE="${KEY_FILE}.pub"
SSH_PASSWORD_OPTS=(
  -p "$PORT"
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  -o IdentitiesOnly=yes
)
REMOTE_TARGET="${USER_NAME}@${HOST}"

mkdir -p "$(dirname "$KEY_FILE")"
chmod 700 "$(dirname "$KEY_FILE")"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Creating new SSH key: $KEY_FILE"
  ssh-keygen -t ed25519 -f "$KEY_FILE" -C "$COMMENT"
else
  echo "Using existing SSH key: $KEY_FILE"
fi

if [[ ! -f "$PUB_KEY_FILE" ]]; then
  echo "Public key not found: $PUB_KEY_FILE" >&2
  exit 1
fi

echo
echo "Copying public key to $REMOTE_TARGET using password authentication."
echo "You may be prompted for the remote password."

if command -v ssh-copy-id >/dev/null 2>&1; then
  ssh-copy-id "${SSH_PASSWORD_OPTS[@]}" -i "$PUB_KEY_FILE" "$REMOTE_TARGET"
else
  PUB_KEY_CONTENT="$(<"$PUB_KEY_FILE")"
  ssh "${SSH_PASSWORD_OPTS[@]}" "$REMOTE_TARGET" \
    "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; grep -qxF '$PUB_KEY_CONTENT' ~/.ssh/authorized_keys || printf '%s\n' '$PUB_KEY_CONTENT' >> ~/.ssh/authorized_keys"
fi

echo
echo "Key installation complete."
echo
echo "Test key-based login with:"
echo "  ssh -i $KEY_FILE -o IdentitiesOnly=yes -p $PORT $REMOTE_TARGET"
echo
echo "After that works, disable password-based SSH on the server:"
echo "  1. Edit /etc/ssh/sshd_config and any active files in /etc/ssh/sshd_config.d/"
echo "  2. Set:"
echo "       PasswordAuthentication no"
echo "       KbdInteractiveAuthentication no"
echo "       ChallengeResponseAuthentication no"
if [[ "$USER_NAME" == "root" ]]; then
  echo "       PermitRootLogin prohibit-password"
fi
echo "  3. Validate the config:"
echo "       sshd -t"
echo "  4. Reload SSH:"
echo "       systemctl restart ssh"
echo
echo "Keep your current server console or password session open until you confirm key login works."
