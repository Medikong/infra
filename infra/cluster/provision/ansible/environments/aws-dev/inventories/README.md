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

기본 경로는 `.local/terraform/<workspace>/inventory.ini`입니다. inventory는 EC2 instance ID를 host로 사용하고 AWS Systems Manager `AWS-StartSSHSession` ProxyCommand를 포함합니다. 로컬에는 AWS CLI, Session Manager plugin, Terraform에 전달한 SSH private key가 필요합니다.

이 환경은 Terraform의 Ubuntu 24.04 ARM64 노드, ECR read-only instance role, 노드별 20GiB root volume과 local storage 전제를 사용합니다. NAT Gateway, NLB, bastion은 만들지 않으며 노드 인바운드는 인터넷에 공개하지 않습니다.
