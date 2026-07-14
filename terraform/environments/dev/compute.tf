resource "aws_instance" "kubernetes" {
  for_each = local.kubernetes_nodes

  ami                         = data.aws_ssm_parameter.ubuntu_arm64_ami.value
  instance_type               = each.value.instance_type
  availability_zone           = each.value.availability_zone
  subnet_id                   = aws_subnet.public[each.value.availability_zone].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.kubernetes_nodes.id]
  iam_instance_profile        = aws_iam_instance_profile.kubernetes_node.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  dynamic "credit_specification" {
    for_each = startswith(each.value.instance_type, "t") ? [1] : []

    content {
      cpu_credits = var.t_instance_cpu_credits
    }
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.volume_size
    encrypted             = true
    kms_key_id            = var.root_volume_kms_key_id
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/cloud-init.sh.tftpl", {
    hostname = each.key
  })

  user_data_replace_on_change = true

  tags = {
    Name                                         = "${local.name_prefix}-${each.key}"
    Role                                         = each.value.role
    Workload                                     = each.value.workload
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
  }
}
