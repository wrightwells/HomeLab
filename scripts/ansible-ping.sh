#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../ansible"
ansible all -m ping
