#!/usr/bin/env bash
set -Eeuo pipefail

base="/opt/HomeLab"

required=(
  "$base/terraform/main.tf"
  "$base/terraform/templates/ansible_inventory.tftpl"
  "$base/ansible/playbooks/site.yml"
  "$base/ansible/roles/common/tasks/main.yml"
  "$base/docker/compose/media/navidrome-compose.yml"
)

failed=0
for item in "${required[@]}"; do
  if [[ -e "$item" ]]; then
    printf '[OK] %s\n' "$item"
  else
    printf '[MISSING] %s\n' "$item"
    failed=1
  fi
done

exit "$failed"
