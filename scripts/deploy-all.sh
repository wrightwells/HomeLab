#!/usr/bin/env bash
set -euo pipefail

# Full helper flow:
# 1. terraform init
# 2. terraform apply
# 3. ansible ping
# 4. ansible-playbook playbooks/site.yml

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/terraform" && terraform init)
(cd "$ROOT/terraform" && terraform apply)
(cd "$ROOT/ansible" && ansible all -m ping)
(cd "$ROOT/ansible" && ansible-playbook playbooks/site.yml)
