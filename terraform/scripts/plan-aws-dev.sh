#!/usr/bin/env bash

set -euo pipefail

terraform_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "${terraform_root}/.." && pwd)"
profile="${AWS_PROFILE:-dropmong-infra-admin}"
region="${AWS_REGION:-ap-northeast-2}"
workspace="dev"

export AWS_PROFILE="${profile}"
export AWS_REGION="${region}"

if ! aws sts get-caller-identity --no-cli-pager >/dev/null 2>&1; then
  printf 'AWS SSO session is missing or expired. Opening login for profile %s.\n' "${profile}"
  aws sso login --profile "${profile}"
fi

account_id="$(aws sts get-caller-identity --no-cli-pager --query Account --output text)"
state_bucket="${TF_STATE_BUCKET:-medikong-terraform-state-${account_id}-${region}}"
aws s3api head-bucket --bucket "${state_bucket}" >/dev/null

local_root="${repo_root}/.local/terraform"
shared_local_dir="${local_root}/shared"
dev_local_dir="${local_root}/${workspace}"
mkdir -p "${shared_local_dir}" "${dev_local_dir}"

write_backend_config() {
  local path="$1"
  local key="$2"
  {
    printf 'bucket       = "%s"\n' "${state_bucket}"
    printf 'key          = "%s"\n' "${key}"
    printf 'region       = "%s"\n' "${region}"
    printf 'encrypt      = true\n'
    printf 'use_lockfile = true\n'
  } > "${path}"
}

write_backend_config \
  "${shared_local_dir}/backend.hcl" \
  "medikong/shared/terraform.tfstate"
write_backend_config \
  "${dev_local_dir}/backend.hcl" \
  "medikong/environments/dev/terraform.tfstate"

terraform fmt -recursive -check -diff "${terraform_root}"

printf '\nPlanning shared AWS resources...\n'
terraform -chdir="${terraform_root}/shared" init -input=false -reconfigure \
  -backend-config="${shared_local_dir}/backend.hcl"
terraform -chdir="${terraform_root}/shared" workspace select default >/dev/null
terraform -chdir="${terraform_root}/shared" plan -input=false \
  -out="${shared_local_dir}/plan.tfplan" "$@"

printf '\nPlanning AWS dev environment...\n'
terraform -chdir="${terraform_root}/environments/dev" init -input=false -reconfigure \
  -backend-config="${dev_local_dir}/backend.hcl"
terraform -chdir="${terraform_root}/environments/dev" workspace select "${workspace}" >/dev/null 2>&1 || \
  terraform -chdir="${terraform_root}/environments/dev" workspace new "${workspace}"
terraform -chdir="${terraform_root}/environments/dev" plan -input=false \
  -var-file="${terraform_root}/environments/dev/terraform.tfvars.example" \
  -out="${dev_local_dir}/plan.tfplan" "$@"

printf '\nSaved plans:\n'
printf '  %s\n' "${shared_local_dir}/plan.tfplan"
printf '  %s\n' "${dev_local_dir}/plan.tfplan"
printf 'No AWS resources were applied.\n'
