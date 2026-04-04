#!/usr/bin/env bash

set -euo pipefail

APPDATA_ROOT="${APPDATA_ROOT:-/mnt/appdata}"
CONTROL_ROOT="${CONTROL_ROOT:-${APPDATA_ROOT}/homelab-control}"
REPO_DEST="${REPO_DEST:-${CONTROL_ROOT}/HomeLab}"
BRANCH="${BRANCH:-main}"

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

if [ ! -d "$REPO_DEST/.git" ]; then
  echo "HomeLab repo not found at ${REPO_DEST}." >&2
  echo "Run ${CONTROL_ROOT}/bin/bootstrap-control-node.sh first." >&2
  exit 1
fi

echo "Updating HomeLab repo in ${REPO_DEST}"
git -C "$REPO_DEST" fetch origin
git -C "$REPO_DEST" checkout "$BRANCH"
git -C "$REPO_DEST" pull --ff-only origin "$BRANCH"

echo "Refreshing Ansible collections"
if [ -f "$REPO_DEST/ansible/requirements.yml" ]; then
  ansible-galaxy collection install -r "$REPO_DEST/ansible/requirements.yml"
fi

echo "Refreshing shared helper scripts"
$SUDO "$REPO_DEST/scripts/publish-control-node-bootstrap.sh"

echo "Running HomeLab Ansible site playbook"
"$REPO_DEST/scripts/ansible-site.sh" "$@"
