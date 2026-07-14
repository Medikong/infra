# aws-dev inventory

AWS inventory는 Git에 커밋하지 않습니다. `terraform/environments/dev`의 `ansible_inventory` output을 저장소 로컬 경로에 생성합니다.

```bash
task terraform:init STACK=environment ENV=dev
task terraform:workspace ENV=dev WORKSPACE=dev
# terraform plan/apply가 완료된 뒤
task terraform:inventory ENV=dev WORKSPACE=dev
task aws-dev:inventory:check WORKSPACE=dev
task aws-dev:syntax WORKSPACE=dev
task aws-dev:bootstrap WORKSPACE=dev
```

기본 경로는 `.local/terraform/<workspace>/inventory.ini`입니다. inventory는 EC2 instance ID와 `amazon.aws.aws_ssm` 연결 플러그인을 사용합니다. SSH ProxyCommand, EC2 Key Pair, 공개키와 개인키는 사용하지 않습니다.

로컬 실행자는 `dropmong-infra-admin` SSO 프로필로 AWS API와 SSM 세션을 인증합니다. GitHub Actions는 OIDC Role의 임시 자격 증명을 사용합니다. 두 경우 모두 Session Manager plugin, `boto3`, `amazon.aws` collection이 필요하며 원격 Ubuntu AMI에는 SSM Agent와 `curl`이 있어야 합니다. Ansible 모듈 파일은 `terraform/shared`의 버전 관리가 꺼진 전용 S3 버킷을 잠시 거친 뒤 삭제됩니다.

`aws_ssm` 연결은 `ansible_user`를 Linux 실행 사용자로 사용하지 않습니다. inventory는 모든 작업을 `sudo`로 root 권한에서 실행하도록 지정하고, Ubuntu 사용자의 kubeconfig 경로는 `kubernetes_admin_user`, `kubernetes_admin_group`, `kubernetes_admin_home`으로 별도 지정합니다.

이 환경은 Terraform의 Ubuntu 24.04 ARM64 노드, ECR read-only instance role, 노드별 20GiB root volume과 local storage 전제를 사용합니다. NAT Gateway, NLB, bastion은 만들지 않으며 노드 인바운드는 인터넷에 공개하지 않습니다.
