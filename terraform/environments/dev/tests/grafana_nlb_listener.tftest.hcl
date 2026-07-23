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

run "grafana_nlb_listener_explicitly_enabled" {
  command = plan

  variables {
    grafana_nlb_listener_enabled = true
  }

  assert {
    condition = (
      length(aws_lb_listener.grafana_http) == 1
      && aws_lb_listener.grafana_http[0].protocol == "TCP"
      && aws_lb_listener.grafana_http[0].port == 80
      && aws_lb_listener.grafana_http[0].default_action[0].target_group_arn == aws_lb_target_group.grafana.arn
    )
    error_message = "Explicit enablement must create exactly one TCP/80 listener forwarding to the Grafana target group."
  }
}
