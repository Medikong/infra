resource "aws_security_group" "kubernetes_nodes" {
  name        = "${local.name_prefix}-kubernetes-nodes-sg"
  description = "Self-managed Kubernetes nodes for ${local.name_prefix}"
  vpc_id      = aws_vpc.environment.id

  tags = {
    Name = "${local.name_prefix}-kubernetes-nodes-sg"
  }
}

resource "aws_security_group" "grafana_nlb" {
  name        = "${local.name_prefix}-grafana-nlb-sg"
  description = "Temporary public Grafana NLB for ${local.name_prefix}"
  vpc_id      = aws_vpc.environment.id

  tags = {
    Name = "${local.name_prefix}-grafana-nlb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "grafana_nlb_http" {
  security_group_id = aws_security_group.grafana_nlb.id
  description       = "Temporary public Grafana HTTP"
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "grafana_nlb_gateway" {
  security_group_id            = aws_security_group.grafana_nlb.id
  description                  = "Dedicated Istio Grafana gateway"
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  from_port                    = 32081
  to_port                      = 32081
}

resource "aws_vpc_security_group_egress_rule" "grafana_nlb_health" {
  security_group_id            = aws_security_group.grafana_nlb.id
  description                  = "Dedicated Istio Grafana readiness"
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  from_port                    = 31836
  to_port                      = 31836
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_internal" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  description                  = "All traffic between Kubernetes nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_grafana_gateway" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  description                  = "Grafana gateway traffic from its NLB"
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.grafana_nlb.id
  from_port                    = 32081
  to_port                      = 32081
}

resource "aws_vpc_security_group_ingress_rule" "kubernetes_grafana_health" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  description                  = "Grafana gateway readiness from its NLB"
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.grafana_nlb.id
  from_port                    = 31836
  to_port                      = 31836
}

resource "aws_vpc_security_group_egress_rule" "kubernetes_nodes_ipv4" {
  security_group_id = aws_security_group.kubernetes_nodes.id
  description       = "Node outbound access through the Internet Gateway"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
