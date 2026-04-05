#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/_common.sh"

cd "$(terraform_env_dir production)"
terraform init -input=false

set +e
terraform plan -input=false -no-color -detailed-exitcode -var-file="$DEFAULT_TERRAFORM_VARS_FILE"
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
