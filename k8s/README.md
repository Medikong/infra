# Kubernetes Manifests

이 디렉터리는 MediKong 서비스의 이전 Kustomize manifest와 overlay를 관리합니다. 현재 aws-dev workload 배포의 source of truth는 GitOps 저장소입니다.

## 배포 구조

| Namespace | 리소스 |
| --- | --- |
| `medical-auth` | auth-service, auth-db, auth Ingress, KongConsumer, JWT Secret |
| `medical-messaging` | Kafka StatefulSet, topic Job |
| `medical-patient` | patient-service, patient-db, patient Ingress |
| `medical-appointment` | appointment-service, appointment-db, appointment Ingress |
| `medical-prescription` | prescription-service, prescription-db, prescription Ingress |
| `medical-notification` | notification-service, notification-db, notification Ingress |
| `medical-dashboard` | dashboard, dashboard Ingress |
| `kong` | Kong Gateway와 Kong Ingress Controller |
| `metallb-system` | MetalLB |

## 주요 디렉터리

```text
k8s/
  base/
    apps/                  # 서비스 Deployment/Service 원본
    deps/                  # PostgreSQL, Kafka, PV 원본
  ingress/                 # 서비스별 Kong Ingress
  kong/                    # Kong Helm values, KongClusterPlugin, consumer
  metallb/                 # MetalLB address pool
  namespaces/              # medical-* namespace
  network-policies/        # namespace 간 ingress 정책
  overlays/local/
    deps/                  # PV, DB, Kafka
    apps/                  # app Deployment/Service, Ingress
    all/                   # namespace, deps, apps, Kong policy 전체
```

## Local Overlay

`overlays/local`은 보존 중인 Kustomize 실험 구성입니다. 클러스터 생성이나 배포 Task와 연결되어 있지 않습니다.

렌더링 확인:

```bash
kubectl kustomize k8s/overlays/local/deps
kubectl kustomize k8s/overlays/local/apps
kubectl kustomize k8s/overlays/local/all
```

## 이미지

로컬에서는 control-plane VM의 local registry를 사용합니다.

```text
10.10.10.10:5000
```

image tag 변경과 적용은 GitOps 저장소에서 관리합니다.

직접 확인:

```bash
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -A -o wide
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get svc -A
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get ingress -A
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pvc -A
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get kongclusterplugins
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get kongconsumers -A
```

## 로컬 전용과 AWS 전용

현재 `overlays/local`은 활성 프로비저닝 명령과 연결되지 않은 kubeadm 실험 자료입니다.

```text
local registry
MetalLB
hostPath PV
PostgreSQL/Kafka StatefulSet
Kong Ingress Controller
```

AWS 배포용 overlay를 만들 때는 ECR, EKS LoadBalancer, EBS 또는 RDS, Secrets Manager 기준으로 별도 overlay를 분리합니다.
