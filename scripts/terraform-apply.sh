#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

TERRAFORM_ENV="${1:-root}"
cd "$(terraform_env_dir "$TERRAFORM_ENV")"

mapfile -t terraform_var_args < <(terraform_var_file_args)
terraform apply "${terraform_var_args[@]}"
