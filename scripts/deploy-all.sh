#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/terraform" && terraform init)
(cd "$ROOT/terraform" && terraform apply)
(cd "$ROOT/ansible" && ansible all -m ping)
(cd "$ROOT/ansible" && ansible-playbook playbooks/site.yml)
