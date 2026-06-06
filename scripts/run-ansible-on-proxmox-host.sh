#!/usr/bin/env bash
# run-ansible-on-proxmox-host.sh -- Run the main HomeLab site playbook from the Proxmox host.
#
# This wrapper is for cases where guests are reachable from the Proxmox host
# but not from your workstation. It expects the repo to already exist on the
# Proxmox host.
#
# Usage:
#   ./scripts/run-ansible-on-proxmox-host.sh
#   ./scripts/run-ansible-on-proxmox-host.sh --limit ai_gpu

set -euo pipefail

PROXMOX_HOST="${PROXMOX_HOST:-root@10.10.99.110}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-/root/HomeLab}"

quoted_args=()
for arg in "$@"; do
  quoted_args+=("$(printf '%q' "$arg")")
done

remote_cmd="cd $(printf '%q' "$REMOTE_REPO_DIR") && ./scripts/ansible-site.sh"
if [ "${#quoted_args[@]}" -gt 0 ]; then
  remote_cmd+=" ${quoted_args[*]}"
fi

ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "$remote_cmd"
