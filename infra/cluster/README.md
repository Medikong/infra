# Kubernetes cluster provisioning

Kubernetes 노드 프로비저닝은 환경별 Taskfile과 공통 Ansible role로 관리합니다. 저장소 루트 `Taskfile.yml`은 아래 Taskfile로 위임만 합니다.

```text
infra/cluster/provision/ansible/
├── ansible.cfg
├── requirements.yml
├── roles/
│   ├── base-os/
│   ├── containerd/
│   ├── kubernetes/
│   ├── control-plane/
│   ├── worker/
│   ├── cni/
│   ├── helm/
│   └── node-labels/
└── environments/
    ├── private-dev/
    └── aws-dev/
```

## private-dev

private-dev는 커밋된 내부 inventory, node1 ProxyJump, Longhorn, 사설 Registry, Secrets, Argo CD 설정을 소유합니다.

```bash
task private-dev:ssh-setup-all
task ssh:private-dev
task private-dev:syntax
task private-dev:bootstrap
```

구현 Taskfile은 `provision/ansible/environments/private-dev/Taskfile.yml`입니다. 기본 inventory는 `inventories/private-dev.ini`, 작업자별 SSH config는 환경 디렉터리의 `.local/private-dev/`에 생성됩니다.

## aws-dev

aws-dev는 Ubuntu ARM64, ECR, Terraform 생성 inventory, 노드별 20GiB root volume과 node-local storage를 전제로 합니다. Terraform의 현재 노드 수와 사양을 Ansible에서 변경하지 않습니다.

```bash
task aws-dev:bootstrap
task aws-dev:apply
task aws-dev:ecr-credential-provider
```

inventory는 `.local/terraform/<workspace>/inventory.ini`에만 생성되며 Git에 추가하지 않습니다. EC2 instance ID와 AWS Systems Manager SSH 세션을 사용하므로 AWS CLI, Session Manager plugin, Terraform에 지정한 SSH private key가 필요합니다.

aws-dev 노드는 EC2 Instance Profile과 kubelet ECR Credential Provider로 private ECR 인증을 자동 획득합니다. Kubernetes의 `ecr-registry` pull Secret이나 12시간 주기의 토큰 갱신은 사용하지 않습니다. 기존 클러스터는 `task aws-dev:ecr-credential-provider`로 한 노드씩 전환하며, 신규 bootstrap은 공통 Kubernetes role에서 같은 설정을 자동 적용합니다.

AWS 네트워크는 현재 Terraform 설계를 그대로 사용합니다. NAT Gateway, NLB, bastion을 만들지 않고 노드 인바운드를 인터넷에 공개하지 않습니다. 패키지와 image 다운로드를 위해 실행 중인 노드가 사용하는 public IPv4 정책도 Terraform 소유입니다.

## 역할 경계

| 영역 | 책임 |
| --- | --- |
| 공통 role | OS 준비, containerd, kubeadm, control plane/worker join, Calico, Helm, label/taint |
| private-dev | ProxyJump, 내부 inventory, Longhorn, 사설 Registry, Secrets, Argo CD |
| aws-dev | Terraform inventory, Ubuntu ARM64 검증, instance role 기반 ECR Credential Provider와 node-local storage 전제 |
| GitOps | workload, namespace, storage class, gateway, observability, 서비스 배포 |

환경별 `group_vars/all.yml`, inventory, site playbook, Taskfile은 서로 참조하지 않습니다. 공통 설치 변경은 `roles/`에서 한 번만 수행합니다.
