#!/usr/bin/env bash

set -euo pipefail

mode="${1:-}"
case "${mode}" in
  plan | apply) ;;
  *)
    printf 'Usage: %s plan|apply\n' "$0" >&2
    exit 2
    ;;
esac

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required.}"

repo_root="${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"

write_backend_config() {
  local path="$1"
  local key="$2"
  {
    printf 'bucket       = "%s"\n' "${TF_STATE_BUCKET}"
    printf 'key          = "%s"\n' "${key}"
    printf 'region       = "ap-northeast-2"\n'
    printf 'encrypt      = true\n'
    printf 'use_lockfile = true\n'
  } > "${path}"
}

write_backend_config \
  "${repo_root}/terraform/shared/backend.hcl" \
  "medikong/shared/terraform.tfstate"
write_backend_config \
  "${repo_root}/terraform/environments/dev/backend.hcl" \
  "medikong/environments/dev/terraform.tfstate"
