#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

TERRAFORM_ENV="${1:-root}"
cd "$(terraform_env_dir "$TERRAFORM_ENV")"
terraform plan -var-file="$DEFAULT_TERRAFORM_VARS_FILE"
