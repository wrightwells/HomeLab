#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/HomeLab/terraform
terraform init
terraform apply "$@"
