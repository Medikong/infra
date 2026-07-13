#!/usr/bin/env bash

set -euo pipefail

mode="${1:-}"
case "${mode}" in
  print | write) ;;
  *)
    printf 'Usage: %s print|write\n' "$0" >&2
    exit 2
    ;;
esac

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
region="${AWS_REGION:-ap-northeast-2}"
project_name="${PROJECT_NAME:-medikong}"
account_id="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
bucket="${TF_STATE_BUCKET:-${project_name}-terraform-state-${account_id}-${region}}"

if [[ "${mode}" == "print" ]]; then
  printf '%s\n' "${bucket}"
  exit 0
fi

{
  printf 'bucket       = "%s"\n' "${bucket}"
  printf 'key          = "medikong/foundation/terraform.tfstate"\n'
  printf 'region       = "%s"\n' "${region}"
  printf 'encrypt      = true\n'
  printf 'use_lockfile = true\n'
} > "${root_dir}/foundation/backend.hcl"

{
  printf 'terraform {\n'
  printf '  backend "s3" {}\n'
  printf '}\n'
} > "${root_dir}/foundation/backend_override.tf"
