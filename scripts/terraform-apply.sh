#!/usr/bin/env bash
set -euo pipefail
# Run Terraform apply from the repo terraform directory.
cd "$(dirname "$0")/../terraform"
terraform apply
