# Infra 레포 작업 지침

## Taskfile 확인 원칙

- 작업 전에 먼저 루트 `Taskfile.yml`을 읽고 현재 공개 진입점을 확인한다.
- 명령어 이름을 이 문서에 고정된 목록처럼 외워서 사용하지 않는다. 실제 실행 가능한 명령은 항상 현재 `Taskfile.yml`을 기준으로 판단한다.
- 루트 `Taskfile.yml`은 개발자가 자주 쓰는 진입점을 소유 폴더로 위임하는 프록시 역할만 한다.
- 루트 `Taskfile.yml`에는 환경별 접속 정보, 노드 IP, 사용자명, key path 같은 구현 설정을 두지 않는다.
- 루트 프록시가 가리키는 소유 폴더의 `Taskfile.yml`을 이어서 읽고 실제 구현과 검증 명령을 확인한다.
- 동일한 기능의 명령어에서 추가 인자를 받아야 하는 경우 명령어 수를 늘리지 말고 `--` 뒤에 전달한다. (예: `task private-dev:bootstrap -- --limit node1`)

## 레포 폴더 구조

- `terraform/foundation/`: Terraform 상태 저장용 S3 버킷, GitHub Actions OIDC provider와 배포용 IAM Role을 별도 state로 관리한다.
- `terraform/shared/`: ECR처럼 환경 전체에서 공유하는 고정 AWS 자원과 별도 state를 정의한다.
- `terraform/environments/<env>/`: VPC, SSM 관리 경로, self-managed Kubernetes 노드처럼 환경별 AWS 자원과 별도 state를 정의한다.
- `terraform/Taskfile.yml`: Terraform 명령 구현을 소유한다. 루트 Taskfile은 이 명령을 프록시만 한다.
- `infra/cluster/`: Kubernetes 클러스터 프로비저닝 작업을 다룬다.
- `infra/cluster/provision/ansible/roles/`: 환경이 공유하는 Kubernetes 설치 role을 관리한다.
- `infra/cluster/provision/ansible/environments/private-dev/`: private-dev inventory, playbook, config, Taskfile을 관리한다.
- `infra/cluster/provision/ansible/environments/aws-dev/`: Terraform inventory를 사용하는 aws-dev playbook과 Taskfile을 관리한다.
- `k8s/`: Kubernetes 기본 매니페스트, 네임스페이스, 네트워크 정책, 스토리지, Kong/MetalLB 같은 클러스터 리소스를 둔다.
- `.local/`: 개발 장비에서 생성되는 로컬 전용 파일 위치다. 커밋하지 않는다.
- 루트 `Taskfile.yml`: 위 폴더들의 작업을 직접 구현하지 않고, 자주 쓰는 진입점만 연결한다.

## Private-Dev SSH 원칙

- 로컬에서 생성되는 작업자별 파일은 `.local/` 아래에 두고 커밋하지 않는다.
- 로컬 장비에서는 node1만 외부 lab endpoint로 접근한다.
- node2-node6 접근은 node1을 경유한다. 로컬에서 node2-node6 외부 포트를 직접 사용하는 구성을 기본값으로 만들지 않는다.
- private key를 node1에 복사하지 않는다. node1에서 다른 노드로 접속할 때는 `ssh-agent` forwarding을 사용한다.
- node1 내부에서 `ssh node2`, `ssh node3`처럼 접근할 수 있도록 node1-local SSH alias를 구성한다.

## 변경 관리

- private-dev SSH/bootstrap 변경과 무관한 Terraform 또는 README 변경은 사용자가 명시하지 않는 한 같은 커밋에 포함하지 않는다.
- 루트 Taskfile을 수정했다면 루트 `Taskfile.yml`을 다시 읽고 프록시 범위만 유지되는지 확인한다.
- 환경 Taskfile을 수정했다면 같은 환경의 inventory, `group_vars/all.yml`, `playbooks/site.yml`을 함께 확인한다.
- 검증 명령은 문서에 적힌 예시보다 현재 Taskfile의 실제 task 정의를 우선한다.
