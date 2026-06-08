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
