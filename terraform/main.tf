provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  name_prefix = "${var.project_name}-${terraform.workspace}"
  common_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
  }
  kong_proxy_cidrs = distinct(concat(var.default_kong_proxy_cidrs, var.additional_kong_proxy_cidrs))
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 키페어 등록
resource "aws_key_pair" "k8s_key" {
  key_name   = "${local.name_prefix}-k8s-key"
  public_key = file(var.public_key_path)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-k8s-key"
  })
}

# 보안그룹
resource "aws_security_group" "k8s_sg" {
  name        = "${local.name_prefix}-k8s-sg"
  description = "Security group for ${local.name_prefix} Kubernetes cluster"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }
  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # K8s API 서버
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_k8s_api_cidrs
  }
  # Kong Proxy NodePort. Keep the CIDR list narrow because this exposes Ingress routes.
  dynamic "ingress" {
    for_each = length(local.kong_proxy_cidrs) > 0 ? [1] : []
    content {
      from_port   = var.kong_proxy_node_port
      to_port     = var.kong_proxy_node_port
      protocol    = "tcp"
      cidr_blocks = local.kong_proxy_cidrs
    }
  }
  # 노드간 통신
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  # 아웃바운드 모두 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-k8s-sg"
  })
}

# 마스터 노드
resource "aws_instance" "master" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = var.master_volume_size
    volume_type = var.volume_type
  }

  user_data = <<-USERDATA
    #!/bin/bash
    (crontab -l 2>/dev/null; echo "0 */10 * * * /bin/bash -c 'ECR_PASSWORD=\$(aws ecr get-login-password --region ap-northeast-2) && for ns in ticketing-auth ticketing-concert ticketing-reservation ticketing-payment ticketing-ticket ticketing-notification ticketing-dashboard; do kubectl delete secret ecr-registry -n \$${ns} --ignore-not-found; kubectl create secret docker-registry ecr-registry --docker-server=941141115079.dkr.ecr.ap-northeast-2.amazonaws.com --docker-username=AWS --docker-password=\$${ECR_PASSWORD} -n \$${ns}; done'") | crontab -
  USERDATA

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-master"
    Role = "master"
  })
}

# 워커 노드
resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = var.ami_id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  depends_on             = [aws_instance.master]

  root_block_device {
    volume_size = var.worker_volume_size
    volume_type = var.volume_type
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-worker-${count.index + 1}"
    Role = "worker"
  })
}

# 서비스 이미지 저장소
resource "aws_ecr_repository" "service" {
  for_each = var.ecr_repositories

  name         = each.key
  force_delete = var.ecr_force_delete

  image_tag_mutability = "MUTABLE"

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-${each.key}"
    Service = each.key
  })
}

# 외부 HTTP 진입점
resource "aws_lb" "kong" {
  name               = "${local.name_prefix}-kong-nlb"
  internal           = var.nlb_internal
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids

  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-nlb"
  })
}

resource "aws_lb_target_group" "kong" {
  name        = "${local.name_prefix}-kong-tg"
  port        = var.nlb_target_port
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled  = true
    protocol = var.nlb_health_check_protocol
    port     = "traffic-port"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-tg"
  })
}

resource "aws_lb_listener" "kong_http" {
  load_balancer_arn = aws_lb.kong.arn
  port              = var.nlb_listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kong-http"
  })
}

resource "aws_lb_target_group_attachment" "kong_worker" {
  count = var.worker_count

  target_group_arn = aws_lb_target_group.kong.arn
  target_id        = aws_instance.worker[count.index].id
  port             = var.nlb_target_port
}

# 출력
output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_private_ips" {
  value = aws_instance.worker[*].private_ip
}

output "security_group_id" {
  value = aws_security_group.k8s_sg.id
}

output "ecr_repository_urls" {
  value = {
    for name, repo in aws_ecr_repository.service : name => repo.repository_url
  }
}

output "nlb_dns_name" {
  value = aws_lb.kong.dns_name
}

output "nlb_target_group_arn" {
  value = aws_lb_target_group.kong.arn
}

output "workspace" {
  value = terraform.workspace
}

# EC2가 ECR에 접근하기 위한 IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

# ECR 읽기 권한 부여
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM Instance Profile (EC2에 Role 연결)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# 마스터 고정 IP
resource "aws_eip" "master" {
  instance = aws_instance.master.id
  domain   = "vpc"
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-master-eip"
  })
}

output "master_eip" {
  value = aws_eip.master.public_ip
}

resource "aws_iam_role_policy" "ebs_csi" {
  name = "${local.name_prefix}-ebs-csi-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateVolume",
        "ec2:DeleteVolume",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:DescribeVolumes",
        "ec2:DescribeInstances",
        "ec2:CreateTags"
      ]
      Resource = "*"
    }]
  })
}
