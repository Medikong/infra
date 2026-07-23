mock_provider "aws" {
  override_during = plan

  mock_resource "aws_instance" {
    defaults = {
      id = "i-0123456789abcdef0"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/net/medikong-dev-grafana/0123456789abcdef"
      dns_name = "medikong-dev-grafana-0123456789abcdef.elb.ap-northeast-2.amazonaws.com"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/medikong-dev-grafana/0123456789abcdef"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Action    = "sts:AssumeRole"
          Principal = { Service = "ec2.amazonaws.com" }
        }]
      })
    }
  }
}

run "grafana_nlb_safe_default" {
  command = plan

  assert {
    condition = (
      aws_lb.grafana.load_balancer_type == "network"
      && !aws_lb.grafana.internal
      && !aws_lb.grafana.enable_cross_zone_load_balancing
      && !aws_lb.grafana.enable_deletion_protection
    )
    error_message = "Grafana must use one removal-safe internet-facing Network Load Balancer."
  }

  assert {
    condition     = length(aws_lb_listener.grafana_http) == 0
    error_message = "The safe default must not create a public Grafana listener."
  }

  assert {
    condition = (
      aws_lb_target_group.grafana.protocol == "TCP"
      && aws_lb_target_group.grafana.port == 32081
      && aws_lb_target_group.grafana.target_type == "instance"
      && aws_lb_target_group.grafana.health_check[0].protocol == "HTTP"
      && aws_lb_target_group.grafana.health_check[0].port == "31836"
      && aws_lb_target_group.grafana.health_check[0].path == "/healthz/ready"
    )
    error_message = "The Grafana target group must reach the dedicated Istio NodePort and HTTP readiness endpoint."
  }

  assert {
    condition = (
      length(aws_lb_target_group_attachment.grafana) == length(aws_instance.kubernetes)
      && alltrue([
        for attachment in aws_lb_target_group_attachment.grafana :
        attachment.port == 32081
      ])
    )
    error_message = "Every Kubernetes instance must be attached only on the dedicated Grafana NodePort."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.grafana_nlb_http.cidr_ipv4 == "0.0.0.0/0"
      && aws_vpc_security_group_ingress_rule.grafana_nlb_http.ip_protocol == "tcp"
      && aws_vpc_security_group_ingress_rule.grafana_nlb_http.from_port == 80
      && aws_vpc_security_group_ingress_rule.grafana_nlb_http.to_port == 80
    )
    error_message = "Only the NLB security group may accept public TCP/80 traffic."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_egress_rule.grafana_nlb_gateway.cidr_ipv4 == null,
      aws_vpc_security_group_egress_rule.grafana_nlb_gateway.ip_protocol == "tcp",
      aws_vpc_security_group_egress_rule.grafana_nlb_gateway.from_port == 32081,
      aws_vpc_security_group_egress_rule.grafana_nlb_gateway.to_port == 32081,
      aws_vpc_security_group_egress_rule.grafana_nlb_health.cidr_ipv4 == null,
      aws_vpc_security_group_egress_rule.grafana_nlb_health.ip_protocol == "tcp",
      aws_vpc_security_group_egress_rule.grafana_nlb_health.from_port == 31836,
      aws_vpc_security_group_egress_rule.grafana_nlb_health.to_port == 31836,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_gateway.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_gateway.ip_protocol == "tcp",
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_gateway.from_port == 32081,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_gateway.to_port == 32081,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_health.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_health.ip_protocol == "tcp",
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_health.from_port == 31836,
      aws_vpc_security_group_ingress_rule.kubernetes_grafana_health.to_port == 31836,
    ])
    error_message = "NLB egress and Kubernetes NodePort ingress must reference only their paired security groups."
  }

  assert {
    condition = (
      output.grafana_nlb_dns_name == aws_lb.grafana.dns_name
      && output.grafana_public_url == "http://${aws_lb.grafana.dns_name}/grafana/"
    )
    error_message = "Terraform must export the generated NLB DNS name and exact Grafana sub-path URL."
  }
}
