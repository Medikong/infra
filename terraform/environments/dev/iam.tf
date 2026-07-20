data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kubernetes_node" {
  name               = "${local.name_prefix}-kubernetes-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-kubernetes-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "kubernetes_node_ssm" {
  role       = aws_iam_role.kubernetes_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "kubernetes_node_ecr_read_only" {
  role       = aws_iam_role.kubernetes_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "kubernetes_node_ebs_csi" {
  role       = aws_iam_role.kubernetes_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "external_secrets" {
  name = "${local.name_prefix}-external-secrets-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "KubernetesNodes"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = aws_iam_role.kubernetes_node.arn }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-external-secrets-role"
  }
}

resource "aws_iam_role_policy" "external_secrets_discord_webhook" {
  name = "${local.name_prefix}-discord-webhook-read"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadAwsDevDiscordWebhook"
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dropmong/aws-dev/discord/webhook-??????"
    }]
  })
}

resource "aws_iam_role_policy" "kubernetes_node_assume_external_secrets" {
  name = "${local.name_prefix}-assume-external-secrets"
  role = aws_iam_role.kubernetes_node.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeExternalSecretsRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.external_secrets.arn
    }]
  })
}

resource "aws_iam_instance_profile" "kubernetes_node" {
  name = "${local.name_prefix}-kubernetes-node-profile"
  role = aws_iam_role.kubernetes_node.name
}
