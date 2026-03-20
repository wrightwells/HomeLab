#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/_common.sh"

cd "$TERRAFORM_DIR"
terraform init -input=false

set +e
terraform plan -input=false -no-color -detailed-exitcode
rc=$?
set -e

case "$rc" in
  0)
    echo "Terraform plan completed with no changes."
    ;;
  2)
    echo "Terraform plan completed and detected changes."
    ;;
  *)
    exit "$rc"
    ;;
esac
