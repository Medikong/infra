# 🏗️ MediKong Infra

> 클라우드 네이티브 의료 정보 플랫폼 — 인프라 구성 및 배포 자동화

---

## 📁 디렉토리 구조

```
infra/
├── infra/cluster/                  # Ansible 기반 K8s 클러스터 구성
│   ├── provision/ansible/
│   │   ├── playbooks/
│   │   │   ├── bootstrap-servers.yml   # K8s 패키지 설치
│   │   │   └── bootstrap-cluster.yml   # 클러스터 초기화 및 서비스 배포
│   │   ├── inventories/aws/dev.ini     # AWS EC2 인벤토리
│   │   └── group_vars/all.yml          # 공통 변수
│   └── Makefile
├── terraform/                      # AWS 인프라 프로비저닝
│   ├── main.tf                         # EC2, 보안그룹, 키페어 정의
│   ├── variables.tf                    # 변수 정의
│   └── terraform.tfvars.example        # 환경변수 예시 (키 입력 필요)
└── k8s/                            # Kubernetes 배포 매니페스트
    ├── base/                           # 기본 리소스 정의
    │   ├── apps/                       # 서비스 Deployment, Service
    │   └── deps/                       # DB, Kafka, Outbox StatefulSet
    └── overlays/
        └── aws/                        # AWS 환경 오버레이
            ├── apps/kustomization.yaml
            └── deps/kustomization.yaml
```

---

## 🚀 배포 흐름

```
terraform apply
      ↓
EC2 생성 (마스터 1 + 워커 2, ARM64 r6g, 서울 리전, Kubernetes 노드용 IAM instance profile 연결)
      ↓
Ansible bootstrap-servers
      ↓
K8s 설치 (kubelet, kubeadm, kubectl v1.34.8)
      ↓
Ansible bootstrap-cluster
      ↓
kubeadm init (프라이빗 IP 자동 수집)
Calico CNI 설치 / 워커 노드 join
GitHub 코드 자동 clone
kubectl apply -k deps (DB, Kafka, Outbox)
kubectl apply -k apps (서비스 배포)
```

---

## ⚙️ 사용 기술

| 분류 | 기술 |
|------|------|
| 인프라 프로비저닝 | Terraform |
| 서버 자동화 | Ansible |
| 클라우드 | AWS EC2 (ap-northeast-2) |
| 컨테이너 오케스트레이션 | Kubernetes v1.34.8 |
| CNI | Calico |
| 배포 관리 | Kustomize |
| 메시징 | Apache Kafka (StatefulSet) |
| 데이터베이스 | PostgreSQL, MongoDB |

---

## 🛠️ 시작하기

### 1. Terraform으로 EC2 생성

```bash
cd terraform/

# terraform.tfvars 생성
cp terraform.tfvars.example terraform.tfvars
# AWS 키 입력

terraform init
terraform workspace new <이름>   # 팀원별 독립 환경
terraform apply
```

### AWS EBS CSI 전제

aws-dev에서 관측성 PVC는 GitOps의 `medikong-aws-gp3` StorageClass를 통해 동적으로 생성한다. Terraform은 Kubernetes `StorageClass`, Loki/Tempo/Grafana/Prometheus PVC values, 정적 EBS volume/PV를 만들지 않는다.

Terraform의 책임은 kubeadm 기반 EC2 노드가 EBS CSI driver를 통해 EBS volume을 생성하고 attach할 수 있도록 master/worker 공통 IAM instance profile을 연결하는 것이다. EC2 root volume의 `volume_type = "gp3"`는 노드 OS 디스크 설정이고, PVC용 gp3 StorageClass와는 별도이다.

EBS CSI driver 설치와 StorageClass 적용은 Terraform 이후 ArgoCD Application/GitOps 단계에서 완료한다.

### 2. Ansible inventory 설정

```bash
# infra/cluster/provision/ansible/inventories/aws/dev.ini 수정
# terraform output으로 확인한 IP 입력
```

### 3. K8s 클러스터 구성

```bash
cd infra/cluster/

# K8s 패키지 설치
make servers-bootstrap

# 클러스터 초기화 및 서비스 자동 배포
make cluster-bootstrap
```

### 온프레미스 private-dev 클러스터 구성

private-dev가 AWS EC2가 아니라 이미 할당된 온프레미스/랩 인스턴스라면 Terraform을 사용하지 않는다. 같은 내부 네트워크에 붙은 6개 노드 정보는 `infra/cluster/provision/ansible-lab/configs/private-dev.yml`과 `infra/cluster/provision/ansible-lab/inventories/lab/private-dev.ini`에서 관리한다.

private-dev 상세 작업은 `infra/cluster/provision/ansible-lab/Taskfile.yml`에 둔다. repo 루트 `Taskfile.yml`은 개발 장비에서 자주 쓰는 진입점만 노출하는 프록시다.

루트에서 사용하는 명령은 다음 세 가지다.

```bash
task --list
task private-dev:ssh-setup-all
task ssh:private-dev
task private-dev:bootstrap
```

로컬 운영자 접속은 node1만 외부 포트를 사용한다. node2-node6은 로컬에서 직접 외부 포트로 접속하지 않고, node1을 ProxyJump로 사용한다. 팀원마다 SSH key가 다를 수 있으므로 로컬 SSH config는 `.local/private-dev/ssh_config`로 생성하고 커밋하지 않는다.

`task ssh:private-dev`는 접속 전에 key 생성과 node1 `authorized_keys` 설치 여부를 확인한다. 이미 key 로그인이 되면 비밀번호를 묻지 않고, 아직 설치되지 않았을 때만 `ssh-copy-id` 단계에서 node1 비밀번호를 한 번 요구한다.

node1 안에서 `ssh node2`, `ssh node3`처럼 접속하려면 한 번만 `task private-dev:ssh-setup-all`을 실행한다. 이 명령은 node2-node6에도 로컬 public key를 설치하고, node1의 `~/.ssh/config`에 node2-node6 alias를 만든다. 이후 `task ssh:private-dev`로 node1에 들어간 뒤 다음처럼 접속한다.

```bash
ssh node2
ssh node3
ssh node4
ssh node5
ssh node6
```

접속 정보가 바뀌면 task 변수로 덮어쓰지 않고 `infra/cluster/provision/ansible-lab/configs/private-dev.yml`을 수정한다.

주요 항목은 `ssh.key_path`, `ssh.user`, `ssh.node1.host`, `ssh.node1.port`, `ssh.peers.node2`-`ssh.peers.node6`이다.

`no such identity: ~/.ssh/medikong-private-dev`가 보이면 아직 로컬 key가 없다는 뜻이다. `task private-dev:ssh-setup-all`을 실행해 key를 만들거나, 이미 쓰는 key가 있으면 `configs/private-dev.yml`의 `ssh.key_path`를 수정한다.

`channel 0: open failed: connect failed: Name or service not known`가 node2-node6에서 보이면 node1이 해당 내부 이름을 해석하지 못한다는 뜻이다. 내부 IP를 확인했다면 `configs/private-dev.yml`의 `ssh.peers` 값을 수정한 뒤 `task private-dev:ssh-setup-all`을 다시 실행한다.

private-dev inventory에는 node2-node6의 외부 IP, NAT endpoint, 외부 port-forward host를 넣지 않는다. node1의 외부 접속 정보는 로컬 SSH config에만 둔다. Ansible inventory는 `private-dev-node1`, `node2` 같은 SSH alias를 사용하며, ansible-lab Taskfile 구현이 node2-node6을 node1 점프 호스트 경유로 생성한다.

노드 간 통신 alias는 사용자별 SSH config가 아니라 시스템 설정으로 관리한다. `bootstrap-private-dev-node-access.yml`이 `/etc/hosts`에 단일 Ansible managed block을 만들고 `/etc/ssh/ssh_config.d/20-private-dev-nodes.conf`를 덮어써서 반복 실행해도 중복 라인을 만들지 않는다. 이 단계 이후 node1에서 같은 OS 사용자 기준으로 `ssh node2`처럼 접근한다.

ansible-lab SSH bootstrap 구현은 node2-node6에 외부 포트로 접근하지 않고, 생성된 SSH config의 ProxyJump 설정을 통해 node1 경유로 public key를 설치한다. 초기 password 입력이 필요한 환경이면 각 노드마다 SSH 비밀번호 프롬프트가 뜰 수 있다.

`node_ip`를 생략하면 playbook이 SSH로 접속한 노드의 기본 IPv4를 자동으로 kubelet `--node-ip`와 kubeadm advertise address에 사용한다.

RHEL/CentOS/EL9 계열 노드는 `SERVER_OS=el9`가 기본이다.

Secret까지 같은 실행에서 만들려면 필요한 환경 변수를 먼저 주입하고 `configs/private-dev.yml`의 `cluster.run_private_dev_secrets`, `cluster.run_ecr_secret` 값을 조정한다.

실행 전에는 다음으로 inventory와 OS 선택을 확인할 수 있다.

```bash
task -d infra/cluster/provision/ansible-lab env:print
task -d infra/cluster/provision/ansible-lab syntax:check
```

---

## ⚠️ 주의사항

```
terraform.tfvars    → AWS 키 포함, 절대 커밋 금지
*.tfstate           → Git 추적 제외
.env                → Git 추적 제외
```

---

## 🏥 관련 레포지토리

| 레포 | 설명 |
|------|------|
| [Medikong/infra](https://github.com/Medikong/infra) | 인프라 구성 (현재) |
| [Medikong/service](https://github.com/Medikong/service) | 마이크로서비스 코드 |
| [Medikong/gitops](https://github.com/Medikong/gitops) | GitOps 배포 설정 |
| [Medikong/workspace](https://github.com/Medikong/workspace) | 팀 공통 |
