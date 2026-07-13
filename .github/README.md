# AWS 개발 환경 배포 설정

`main` push는 Terraform 검사만 실행합니다. AWS 변경은 `main`에 포함된 커밋에 인프라 태그를 생성했을 때만 실행하며, 저장된 Terraform plan은 `aws-dev` Environment 승인 후 적용합니다.

## 1. AWS SSO 최초 설정

AWS Access Portal: [https://d-9b675860d9.awsapps.com/start](https://d-9b675860d9.awsapps.com/start)

```bash
# SSO start URL: https://d-9b675860d9.awsapps.com/start
aws configure sso --profile dropmong-infra-admin
aws configure set region ap-northeast-2 --profile dropmong-infra-admin
aws configure set output json --profile dropmong-infra-admin
aws sso login --profile dropmong-infra-admin
aws sts get-caller-identity --profile dropmong-infra-admin
```

## 2. 배포 기반 최초 구성

`terraform/foundation`이 Terraform 상태 저장용 S3 버킷, GitHub Actions OIDC provider와 배포용 IAM Role을 생성합니다.

```bash
export AWS_PROFILE=dropmong-infra-admin
export AWS_REGION=ap-northeast-2
task terraform:foundation:bootstrap
```

최초 실행은 로컬 state로 배포 기반 자원을 만든 뒤 foundation state를 생성한 S3 버킷으로 이전합니다. 이후 foundation 변경은 다음 한 명령으로 적용합니다. GitHub Actions 배포 Role은 foundation 자체를 변경하지 않으며, 이 명령은 로컬 AWS 관리자 인증으로만 실행합니다.

```bash
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:apply CONFIRM=foundation
```

## 3. GitHub Variables

GitHub 저장소의 Settings > Secrets and variables > Actions > Variables에 등록합니다.

| 이름 | 값 |
| --- | --- |
| `AWS_ROLE_ARN` | foundation이 생성한 GitHub 배포 Role ARN |
| `TF_STATE_BUCKET` | foundation이 생성한 상태 저장용 버킷 이름 |
| `AWS_DEV_SSH_PUBLIC_KEY` | `~/.ssh/k8s-key.pub` 내용 |

GitHub CLI를 사용하면 다음과 같이 등록할 수 있습니다.

```bash
export AWS_ROLE_ARN="$(AWS_PROFILE=dropmong-infra-admin task --silent terraform:foundation:output -- -raw github_actions_role_arn)"
export TF_STATE_BUCKET="$(AWS_PROFILE=dropmong-infra-admin task --silent terraform:foundation:output -- -raw terraform_state_bucket)"
gh variable set AWS_ROLE_ARN --body "${AWS_ROLE_ARN}"
gh variable set TF_STATE_BUCKET --body "${TF_STATE_BUCKET}"
gh variable set AWS_DEV_SSH_PUBLIC_KEY --body "$(cat ~/.ssh/k8s-key.pub)"
```

## 4. GitHub Environment

GitHub 저장소의 Settings > Environments에서 `aws-dev` Environment를 만들고 다음 항목을 설정합니다.

- Required reviewers 지정
- Prevent self-review 활성화
- Deployment branches and tags에서 `infra-aws-dev-*` 태그만 허용
- Environment secret `AWS_DEV_SSH_PRIVATE_KEY` 등록

```bash
gh secret set AWS_DEV_SSH_PRIVATE_KEY --env aws-dev < ~/.ssh/k8s-key
```

## 5. Git 규칙

- `main`은 Pull Request로만 변경하도록 branch ruleset을 적용합니다.
- `infra-aws-dev-*`는 tag ruleset으로 생성 권한을 배포 담당자에게 제한합니다.
- 인프라 태그의 수정과 삭제를 금지합니다.
- 태그는 반드시 `main`에 포함된 커밋에서 생성합니다. 워크플로도 이 조건을 다시 검사합니다.
- `shared`와 `dev` apply는 태그 작업에서만 허용하며, 개인 `sandbox-*` workspace는 로컬에서 관리할 수 있습니다.

## 6. 배포

최초 구성은 공유 ECR과 AWS 개발 환경을 함께 생성합니다.

```bash
git switch main
git pull --ff-only
git tag -a infra-aws-dev-bootstrap-v0.1.0 -m "Bootstrap AWS dev"
git push origin infra-aws-dev-bootstrap-v0.1.0
```

이후 변경은 AWS 개발 환경에만 적용합니다.

```bash
git switch main
git pull --ff-only
git tag -a infra-aws-dev-v0.1.1 -m "Release AWS dev v0.1.1"
git push origin infra-aws-dev-v0.1.1
```
