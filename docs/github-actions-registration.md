# GitHub Actions AWS 배포 등록 매뉴얼

`Medikong/infra`의 AWS dev 배포 워크플로를 사용하기 위해 GitHub에서 Repository Variables와 `aws-dev` Environment를 설정하는 방법입니다.

## 1. 사전 준비

GitHub 설정에 사용할 Terraform 상태 버킷 이름과 OIDC Role ARN은 `terraform/foundation`에서 관리합니다. 로컬에서는 AWS CLI의 `dropmong-infra-admin` IAM Identity Center 프로필로 로그인합니다.

```bash
aws sso login --profile dropmong-infra-admin
```

`foundation`을 처음 만드는 계정에서는 다음 명령을 한 번 실행합니다.

```bash
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:bootstrap
```

`foundation`이 이미 배포된 계정에서는 변경 계획을 확인한 뒤 적용합니다.

```bash
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:plan
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:apply CONFIRM=foundation
```

GitHub에 등록할 값은 `foundation` 출력값에서 확인합니다.

```bash
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:output
```

출력에서 다음 두 값을 사용합니다.

| Terraform output | GitHub Repository Variable |
| --- | --- |
| `github_actions_role_arn` | `AWS_ROLE_ARN` |
| `terraform_state_bucket` | `TF_STATE_BUCKET` |

## 2. Repository Variables 등록

[Medikong/infra Actions Variables](https://github.com/Medikong/infra/settings/variables/actions)로 이동합니다.

1. `Variables` 탭을 선택합니다.
2. `New repository variable`을 누릅니다.
3. Name과 Value를 입력합니다.
4. `Add variable`을 누릅니다.
5. 아래 두 항목을 같은 방법으로 등록합니다.

| Name | Value |
| --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::205623789422:role/medikong-github-infra-deployer` |
| `TF_STATE_BUCKET` | `medikong-terraform-state-205623789422-ap-northeast-2` |

워크플로는 `AWS_ROLE_ARN`에 지정한 Role을 맡아 AWS 작업을 수행하고, `TF_STATE_BUCKET`에 Terraform 상태를 저장합니다.

참고: [GitHub Actions Variables](https://docs.github.com/en/actions/concepts/workflows-and-actions/variables)

## 3. aws-dev Environment 생성

[Medikong/infra Environments](https://github.com/Medikong/infra/settings/environments)로 이동합니다.

1. `New environment`를 누릅니다.
2. Environment name에 `aws-dev`를 입력합니다.
3. `Configure environment`를 누릅니다.

워크플로의 `apply` 작업은 이름이 `aws-dev`인 Environment를 사용합니다.

참고: [GitHub 배포 환경 관리](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

## 4. 배포 승인 설정

`aws-dev` Environment 설정 화면의 `Deployment protection rules`에서 설정합니다.

1. `Required reviewers`를 활성화합니다.
2. 배포를 승인할 사용자 또는 팀을 추가합니다.
3. 배포 실행자와 다른 승인자가 있다면 `Prevent self-review`를 활성화합니다.
4. `Save protection rules`를 눌러 저장합니다.

1인 운영 중에 `Prevent self-review`를 활성화하면 본인이 시작한 작업을 승인할 수 없습니다. 운영 인원에 맞춰 승인자와 이 옵션을 설정합니다.

## 5. 배포 태그 제한

같은 화면의 `Deployment branches and tags`에서 설정합니다.

1. `Selected branches and tags`를 선택합니다.
2. `Add deployment branch or tag rule`을 누릅니다.
3. `Ref type`에서 `Tag`를 선택합니다.
4. 이름 패턴에 `infra-aws-dev-*`를 입력합니다.
5. `Add rule`을 눌러 저장합니다.

이 규칙은 `aws-dev` Environment를 사용하는 `apply` 작업의 배포 태그를 제한합니다.

참고: [GitHub Deployment protection rules](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

## 6. GitHub Actions의 AWS 인증 방식

이 절은 GitHub에서 추가 항목을 등록하는 절차가 아니라 `AWS_ROLE_ARN`이 어떻게 사용되는지 설명합니다.

GitHub Actions를 AWS 작업자라고 생각하면 다음과 같습니다.

- OIDC 토큰은 GitHub가 작업자에게 발급하는 일회용 신분증입니다.
- IAM Role은 AWS가 신분을 확인한 뒤 잠시 빌려주는 출입 카드입니다.
- `AWS_ROLE_ARN`은 GitHub가 어떤 출입 카드를 빌릴지 알려 주는 주소입니다.

사용자는 `foundation` 출력의 `github_actions_role_arn`과 GitHub의 `AWS_ROLE_ARN` 값이 같은지만 확인하면 됩니다. OIDC 신뢰 정책은 `terraform/foundation`이 관리하고, 토큰 발급 권한은 `.github/workflows/aws-dev-release.yml`이 관리합니다.

```bash
AWS_PROFILE=dropmong-infra-admin task terraform:foundation:output
```

## 7. SSM과 Ansible 전송 버킷의 역할

AWS dev의 Ansible inventory는 EC2 인스턴스 ID와 `amazon.aws.aws_ssm` 연결 플러그인을 사용합니다. GitHub Actions의 `apply` 작업은 Terraform 적용 후 같은 OIDC Role로 SSM 세션을 열어 Kubernetes를 구성합니다.

Ansible 모듈 파일은 `terraform/shared`가 관리하는 다음 전용 S3 버킷을 잠시 사용합니다.

```text
medikong-ansible-transfer-205623789422-ap-northeast-2
```

이 버킷에는 퍼블릭 액세스 차단, AES256 암호화, 1일 뒤 만료되는 lifecycle이 적용되며 버전 관리는 비활성 상태입니다. Terraform 상태는 `TF_STATE_BUCKET`에 별도로 보관합니다.

## 8. 배포 태그 사용

배포 태그는 `origin/main`에 포함된 커밋을 가리켜야 하며 시맨틱 버전 형식을 사용합니다.

| 목적 | 태그 형식 | 실행 범위 |
| --- | --- | --- |
| 최초 배포 또는 `shared` 변경 | `infra-aws-dev-bootstrap-v0.1.0` | `shared`와 AWS dev 환경 |
| 일반 AWS dev 변경 | `infra-aws-dev-v0.1.1` | AWS dev 환경 |

태그를 푸시하면 `plan` 작업이 먼저 실행됩니다. `plan`이 성공하면 `apply` 작업이 `aws-dev` Environment의 승인을 기다리고, 승인 후 Terraform 적용과 Ansible 구성을 실행합니다.

Task 명령은 다음 버전을 계산하고 설명이 포함된 태그를 만들어 `origin`에 푸시합니다.

```bash
# 태그와 버전만 미리 확인
task aws-dev:deploy:tag MODE=bootstrap BUMP=patch DRY_RUN=true

# 최초 배포 또는 shared 변경 배포
task aws-dev:deploy:tag MODE=bootstrap BUMP=patch

# 일반 AWS dev 변경 배포
task aws-dev:deploy:tag MODE=release BUMP=patch
```

`BUMP`은 `patch`, `minor`, `major` 중 하나를 사용합니다. 실제 태그를 만들 때는 작업 트리가 깨끗하고 로컬 `main`이 `origin/main`과 일치해야 합니다. 태그 푸시는 GitHub Actions 배포를 시작하며, `aws-dev` Environment 승인 후 실제 적용이 진행됩니다.

## 9. 로컬 사전 검증

배포 태그를 만들기 전에 저장소 루트에서 다음 명령으로 `shared`와 AWS dev Terraform 계획을 확인합니다.

```bash
task aws-dev:plan -- -no-color
```

이 명령은 `dropmong-infra-admin` SSO 프로필로 로그인하고 Terraform backend를 준비한 뒤 `shared`와 dev 계획 파일을 `.local/terraform/` 아래에 저장합니다.

## 10. 등록 결과 확인

GitHub 페이지에서 다음 항목을 확인합니다.

| 위치 | 설정 항목 | 값 |
| --- | --- | --- |
| Repository Variables | `AWS_ROLE_ARN` | `arn:aws:iam::205623789422:role/medikong-github-infra-deployer` |
| Repository Variables | `TF_STATE_BUCKET` | `medikong-terraform-state-205623789422-ap-northeast-2` |
| Environments | Environment name | `aws-dev` |
| `aws-dev` Deployment protection rules | Required reviewers | 배포 승인 사용자 또는 팀 |
| `aws-dev` Deployment branches and tags | Tag | `infra-aws-dev-*` |

## 11. 문제 해결

### OIDC Role을 맡지 못하는 경우

1. `AWS_ROLE_ARN` 값이 `foundation` 출력값과 같은지 확인합니다.
2. 배포 태그가 `infra-aws-dev-*` 패턴과 시맨틱 버전 형식을 만족하는지 확인합니다.
3. 태그가 가리키는 커밋이 `origin/main`에 포함되어 있는지 확인합니다.
4. 워크플로 작업에 `id-token: write`가 설정되어 있는지 확인합니다.
5. `foundation`의 OIDC 신뢰 정책에 배포 태그와 `aws-dev` Environment subject가 포함되어 있는지 확인합니다.

### Terraform 상태에 접근하지 못하는 경우

1. `TF_STATE_BUCKET` 값이 `foundation` 출력값과 같은지 확인합니다.
2. `foundation` 변경 사항이 AWS 계정에 적용되어 있는지 확인합니다.
3. 로컬 검증에서는 `dropmong-infra-admin` SSO 세션과 현재 AWS 계정을 확인합니다.

### SSM 연결에 실패하는 경우

1. EC2 인스턴스에 SSM Instance Profile이 연결되어 있는지 확인합니다.
2. 인스턴스의 SSM Agent가 실행 중인지 확인합니다.
3. 인스턴스가 SSM 서비스와 전송 버킷에 접근할 수 있는지 확인합니다.
4. OIDC Role에 SSM 세션과 전송 버킷 객체 작업 권한이 연결되어 있는지 확인합니다.
5. `apply` 작업에서 Session Manager plugin, `boto3`, `amazon.aws` collection 설치 단계가 성공했는지 확인합니다.
