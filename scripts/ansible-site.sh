#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/HomeLab
ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/site.yml "$@"
