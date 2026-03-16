#!/usr/bin/env bash
set -euo pipefail
# Ping all hosts in the Ansible inventory.
cd "$(dirname "$0")/../ansible"
ansible all -m ping
