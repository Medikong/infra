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
: "${AWS_DEV_SSH_PUBLIC_KEY:?AWS_DEV_SSH_PUBLIC_KEY is required.}"

repo_root="${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"
ci_dir="${repo_root}/.local/ci"
public_key_path="${ci_dir}/k8s-key.pub"
private_key_path="${HOME}/.ssh/k8s-key"

mkdir -p "${ci_dir}" "${HOME}/.ssh"
umask 077
printf '%s\n' "${AWS_DEV_SSH_PUBLIC_KEY}" > "${public_key_path}"
ssh-keygen -l -f "${public_key_path}" >/dev/null

if [[ "${mode}" == "apply" ]]; then
  : "${AWS_DEV_SSH_PRIVATE_KEY:?AWS_DEV_SSH_PRIVATE_KEY is required in apply mode.}"
  printf '%s\n' "${AWS_DEV_SSH_PRIVATE_KEY}" | sed 's/\r$//' > "${private_key_path}"
  chmod 600 "${private_key_path}"
  derived_public_key="$(ssh-keygen -y -f "${private_key_path}")"
  expected_public_key="$(awk '{ print $1, $2 }' "${public_key_path}")"
  actual_public_key="$(printf '%s\n' "${derived_public_key}" | awk '{ print $1, $2 }')"
  [[ "${actual_public_key}" == "${expected_public_key}" ]] || {
    printf 'AWS_DEV_SSH_PRIVATE_KEY does not match AWS_DEV_SSH_PUBLIC_KEY.\n' >&2
    exit 2
  }
fi

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

{
  printf 'public_key_path  = "%s"\n' "${public_key_path}"
  printf 'private_key_path = "%s"\n' "${private_key_path}"
} > "${ci_dir}/aws-dev.tfvars"
