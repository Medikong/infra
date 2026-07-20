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

resource "aws_iam_instance_profile" "kubernetes_node" {
  name = "${local.name_prefix}-kubernetes-node-profile"
  role = aws_iam_role.kubernetes_node.name
}
