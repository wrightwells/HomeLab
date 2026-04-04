#!/usr/bin/env bash

set -euo pipefail

APPDATA_ROOT="${APPDATA_ROOT:-/mnt/appdata}"
MEDIA_ROOT="${MEDIA_ROOT:-/mnt/media_pool}"
APPDATA_TAG="${APPDATA_TAG:-homelab-appdata}"
MEDIA_TAG="${MEDIA_TAG:-homelab-media-pool}"
CONTROL_ROOT="${CONTROL_ROOT:-${APPDATA_ROOT}/homelab-control}"
REPO_URL="${REPO_URL:-https://github.com/wrightwells/HomeLab.git}"
REPO_DEST="${REPO_DEST:-${CONTROL_ROOT}/HomeLab}"

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "Installing control-node packages"
$SUDO apt-get update
$SUDO apt-get install -y git ansible openssh-client rsync python3 python3-pip curl wget vim jq

if ! mountpoint -q "$APPDATA_ROOT"; then
  echo "Shared appdata is not mounted at ${APPDATA_ROOT}." >&2
  echo "Mount the shared storage first, then rerun this script." >&2
  exit 1
fi

echo "Preparing shared control-node workspace"
$SUDO mkdir -p "$CONTROL_ROOT"
$SUDO chown "$(id -u)":"$(id -g)" "$CONTROL_ROOT"

if [ ! -d "$REPO_DEST/.git" ]; then
  git clone "$REPO_URL" "$REPO_DEST"
else
  git -C "$REPO_DEST" pull --ff-only
fi

if [ -f "$REPO_DEST/ansible/requirements.yml" ]; then
  ansible-galaxy collection install -r "$REPO_DEST/ansible/requirements.yml"
fi

cat <<EOF
Done.

Repo: $REPO_DEST

Next:
  cd "$REPO_DEST/ansible"
  ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml
EOF
