#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-git@github.com:wrightwells/HomeLab.git}"
REPO_DEST="${REPO_DEST:-$HOME/HomeLab}"
BRANCH="${BRANCH:-main}"
SSH_KEY_FILE="${SSH_KEY_FILE:-$HOME/.ssh/id_ed25519}"
SSH_KEY_COMMENT="${SSH_KEY_COMMENT:-$(id -un)@$(hostname -s)}"

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

ensure_ssh_key() {
  mkdir -p "$(dirname "$SSH_KEY_FILE")"
  chmod 700 "$(dirname "$SSH_KEY_FILE")"

  if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Creating SSH key at ${SSH_KEY_FILE}"
    ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -C "$SSH_KEY_COMMENT" -N ""
  fi

  chmod 600 "$SSH_KEY_FILE"
  chmod 644 "${SSH_KEY_FILE}.pub"
}

ensure_passwordless_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    return 0
  fi

  echo "Enabling passwordless sudo for $(id -un)"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$(id -un)" | \
    $SUDO tee "/etc/sudoers.d/90-$(id -un)-homelab-control" >/dev/null
  $SUDO chmod 440 "/etc/sudoers.d/90-$(id -un)-homelab-control"
}

echo "Installing control-node packages"
$SUDO apt-get update
$SUDO apt-get install -y git ansible openssh-client rsync python3 python3-pip curl wget vim jq

ensure_ssh_key
ensure_passwordless_sudo

mkdir -p "$(dirname "$REPO_DEST")"

if [ ! -d "$REPO_DEST/.git" ]; then
  echo "Cloning HomeLab into ${REPO_DEST}"
  git clone "$REPO_URL" "$REPO_DEST"
else
  echo "Updating HomeLab in ${REPO_DEST}"
  git -C "$REPO_DEST" fetch origin
  git -C "$REPO_DEST" checkout "$BRANCH"
  git -C "$REPO_DEST" pull --ff-only origin "$BRANCH"
fi

echo "Refreshing Ansible collections"
if [ -f "$REPO_DEST/ansible/requirements.yml" ]; then
  ansible-galaxy collection install -r "$REPO_DEST/ansible/requirements.yml"
fi

echo
echo "Control-node SSH public key:"
cat "${SSH_KEY_FILE}.pub"
echo
echo "Make sure this key is trusted by the target hosts before rerunning Ansible if SSH auth still fails."

echo "Running HomeLab Ansible site playbook"
"$REPO_DEST/scripts/ansible-site.sh" "$@"
