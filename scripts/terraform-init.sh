#!/usr/bin/env bash

source "$(dirname "$0")/_common.sh"

cd "$TERRAFORM_DIR"
terraform init
