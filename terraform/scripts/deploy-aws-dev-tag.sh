#!/usr/bin/env bash

set -euo pipefail

mode="${MODE:-release}"
bump="${BUMP:-patch}"
dry_run="${DRY_RUN:-false}"
remote="origin"
branch="main"
terraform_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "${terraform_root}/.." && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage:
  task aws-dev:deploy:tag MODE=<bootstrap|release> BUMP=<patch|minor|major> [DRY_RUN=true]

MODE:
  bootstrap  Deploy shared resources and the AWS dev environment.
  release    Deploy only the AWS dev environment. This is the default.
EOF
}

case "${mode}" in
  bootstrap | release) ;;
  *)
    usage
    printf 'Invalid MODE=%s. Expected bootstrap or release.\n' "${mode}" >&2
    exit 2
    ;;
esac

case "${bump}" in
  patch | minor | major) ;;
  *)
    usage
    printf 'Invalid BUMP=%s. Expected patch, minor, or major.\n' "${bump}" >&2
    exit 2
    ;;
esac

case "${dry_run}" in
  true | false) ;;
  *)
    printf 'Invalid DRY_RUN=%s. Expected true or false.\n' "${dry_run}" >&2
    exit 2
    ;;
esac

cd "${repo_root}"

git remote get-url "${remote}" >/dev/null

current_branch="$(git branch --show-current)"
if [[ "${current_branch}" != "${branch}" ]]; then
  printf 'AWS dev release tags must be created from %s, not %s.\n' "${branch}" "${current_branch:-detached HEAD}" >&2
  exit 2
fi

git fetch --tags --force "${remote}"
git fetch --no-tags "${remote}" "+refs/heads/${branch}:refs/remotes/${remote}/${branch}"

head_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse "refs/remotes/${remote}/${branch}")"
if [[ "${head_sha}" != "${remote_sha}" ]]; then
  printf 'Local %s must match %s/%s before creating a release tag.\n' "${branch}" "${remote}" "${branch}" >&2
  printf 'local:  %s\nremote: %s\n' "${head_sha}" "${remote_sha}" >&2
  exit 2
fi

if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "${dry_run}" == "true" ]]; then
    printf 'Warning: the worktree has uncommitted changes; a real release would stop here.\n' >&2
  else
    printf 'Commit and push all intended changes before creating an AWS dev release tag.\n' >&2
    exit 2
  fi
fi

latest_version="$({
  git tag --list 'infra-aws-dev-bootstrap-v[0-9]*.[0-9]*.[0-9]*'
  git tag --list 'infra-aws-dev-v[0-9]*.[0-9]*.[0-9]*'
} | sed -nE 's/^infra-aws-dev-(bootstrap-)?v([0-9]+)\.([0-9]+)\.([0-9]+)$/\2.\3.\4/p' |
  awk -F. 'NF == 3 { printf "%d.%d.%d\n", $1, $2, $3 }' |
  sort -t. -k1,1n -k2,2n -k3,3n |
  tail -n 1)"

if [[ -z "${latest_version}" ]]; then
  if [[ "${mode}" != "bootstrap" ]]; then
    printf 'No AWS dev release tag exists. Start with MODE=bootstrap.\n' >&2
    exit 2
  fi
  next_version="0.1.0"
else
  IFS=. read -r major minor patch <<EOF
${latest_version}
EOF

  case "${bump}" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
  esac
  next_version="${major}.${minor}.${patch}"
fi

case "${mode}" in
  bootstrap)
    tag_name="infra-aws-dev-bootstrap-v${next_version}"
    tag_message="Bootstrap AWS dev v${next_version}"
    ;;
  release)
    tag_name="infra-aws-dev-v${next_version}"
    tag_message="Release AWS dev v${next_version}"
    ;;
esac

if git rev-parse -q --verify "refs/tags/${tag_name}" >/dev/null; then
  printf 'Tag already exists: %s\n' "${tag_name}" >&2
  exit 2
fi

printf 'AWS dev release tag preview:\n'
printf '  mode: %s\n' "${mode}"
printf '  bump: %s\n' "${bump}"
printf '  source: %s\n' "${head_sha}"
printf '  tag: %s\n' "${tag_name}"

if [[ "${dry_run}" == "true" ]]; then
  printf 'DRY_RUN=true: tag creation and push skipped.\n'
  exit 0
fi

git tag -a "${tag_name}" -m "${tag_message}"
git push "${remote}" "refs/tags/${tag_name}"
printf 'Pushed AWS dev release tag: %s\n' "${tag_name}"
