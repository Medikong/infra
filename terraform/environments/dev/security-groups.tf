resource "aws_security_group" "kubernetes_nodes" {
  name        = "${local.name_prefix}-kubernetes-nodes-sg"
  description = "Self-managed Kubernetes nodes for ${local.name_prefix}"
  vpc_id      = aws_vpc.environment.id

  tags = {
    Name = "${local.name_prefix}-kubernetes-nodes-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_internal" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  description                  = "All traffic between Kubernetes nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
}

resource "aws_vpc_security_group_egress_rule" "kubernetes_nodes_ipv4" {
  security_group_id = aws_security_group.kubernetes_nodes.id
  description       = "Node outbound access through the Internet Gateway"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
