#!/usr/bin/env bash
set -euo pipefail
# Run Terraform init from the repo terraform directory.
cd "$(dirname "$0")/../terraform"
terraform init
