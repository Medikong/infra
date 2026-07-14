# GitHub Actions 등록 매뉴얼

`Medikong/infra`의 AWS 배포 워크플로에 필요한 Repository Variables와 `aws-dev` Environment를 GitHub 페이지에서 등록하는 방법입니다.

## 1. Repository Variables 등록

[Medikong/infra Actions Variables](https://github.com/Medikong/infra/settings/variables/actions)로 이동합니다.

1. `Variables` 탭을 선택합니다.
2. `New repository variable`을 누릅니다.
3. Name과 Value를 입력합니다.
4. `Add variable`을 누릅니다.
5. 아래 세 항목을 같은 방법으로 모두 등록합니다.

### AWS_ROLE_ARN

Name:

```text
AWS_ROLE_ARN
```

Value:

```text
arn:aws:iam::205623789422:role/medikong-github-infra-deployer
```

### TF_STATE_BUCKET

Name:

```text
TF_STATE_BUCKET
```

Value:

```text
medikong-terraform-state-205623789422-ap-northeast-2
```

### AWS_DEV_SSH_PUBLIC_KEY

Name:

```text
AWS_DEV_SSH_PUBLIC_KEY
```

macOS 터미널에서 공개키를 복사합니다.

```bash
pbcopy < ~/.ssh/k8s-key.pub
```

복사한 한 줄 전체를 Value에 붙여 넣습니다. 값은 `ssh-rsa`로 시작합니다.

Repository Variables에는 개인키, 비밀번호 또는 AWS Access Key를 등록하지 않습니다.

참고: [GitHub Actions Variables](https://docs.github.com/en/actions/concepts/workflows-and-actions/variables)

## 2. aws-dev Environment 생성

[Medikong/infra Environments](https://github.com/Medikong/infra/settings/environments)로 이동합니다.

1. `New environment`를 누릅니다.
2. Environment name에 `aws-dev`를 입력합니다.
3. `Configure environment`를 누릅니다.

환경 이름은 대소문자를 포함해 `aws-dev`로 등록합니다.

참고: [GitHub 배포 환경 관리](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

## 3. Environment Secret 등록

생성한 `aws-dev` Environment 설정 화면에서 다음 순서로 등록합니다.

1. `Environment secrets`로 이동합니다.
2. `Add environment secret`을 누릅니다.
3. Name에 `AWS_DEV_SSH_PRIVATE_KEY`를 입력합니다.
4. 아래 명령으로 개인키를 복사합니다.

```bash
pbcopy < ~/.ssh/k8s-key
```

5. 복사한 값을 Secret에 붙여 넣습니다.
6. `Add secret`을 누릅니다.

개인키의 시작 줄과 끝 줄을 포함한 전체 내용이 들어가야 합니다.

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

개인키는 `aws-dev` Environment Secret에만 등록합니다. GitHub는 등록된 Secret 값을 다시 보여 주지 않으므로 잘못 입력했다면 같은 이름으로 값을 갱신합니다.

참고: [GitHub Environment Secrets](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments#environment-secrets)

## 4. 승인자 설정

`aws-dev` Environment 설정 화면의 `Deployment protection rules`에서 설정합니다.

1. `Required reviewers`를 활성화합니다.
2. 배포를 승인할 사용자 또는 팀을 추가합니다.
3. 배포 실행자와 다른 승인자가 있다면 `Prevent self-review`를 활성화합니다.
4. 변경 사항을 저장합니다.

1인 운영 중에 `Prevent self-review`를 활성화하면 본인이 시작한 작업을 승인할 수 없습니다. 이 경우 다른 승인자를 추가하거나 `Prevent self-review`를 비활성화합니다.

## 5. 배포 태그 제한

같은 화면의 `Deployment branches and tags`에서 설정합니다.

1. `Selected branches and tags`를 선택합니다.
2. `Add deployment branch or tag rule`을 누릅니다.
3. 규칙 종류로 `Tag`를 선택합니다.
4. 이름 패턴에 `infra-aws-dev-*`를 입력합니다.
5. 규칙을 저장합니다.

참고: [GitHub Deployment protection rules](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

## 6. 등록 결과 확인

GitHub 페이지에서 다음 항목을 확인합니다.

| 위치 | 등록 항목 |
| --- | --- |
| Repository Variables | `AWS_ROLE_ARN` |
| Repository Variables | `TF_STATE_BUCKET` |
| Repository Variables | `AWS_DEV_SSH_PUBLIC_KEY` |
| `aws-dev` Environment secrets | `AWS_DEV_SSH_PRIVATE_KEY` |
| `aws-dev` Deployment protection rules | Required reviewers |
| `aws-dev` Deployment branches and tags | `infra-aws-dev-*` |
