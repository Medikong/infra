resource "aws_lb" "grafana" {
  name_prefix                      = "graf-"
  internal                         = false
  load_balancer_type               = "network"
  security_groups                  = [aws_security_group.grafana_nlb.id]
  subnets                          = values(aws_subnet.public)[*].id
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = false

  tags = {
    Name = "${local.name_prefix}-grafana-nlb"
  }
}

resource "aws_lb_target_group" "grafana" {
  name_prefix = "graf-"
  port        = 32081
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.environment.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 6
    protocol            = "HTTP"
    port                = "31836"
    path                = "/healthz/ready"
    matcher             = "200-399"
  }

  tags = {
    Name = "${local.name_prefix}-grafana"
  }
}

resource "aws_lb_target_group_attachment" "grafana" {
  for_each = aws_instance.kubernetes

  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = each.value.id
  port             = 32081
}

resource "aws_lb_listener" "grafana_http" {
  count = var.grafana_nlb_listener_enabled ? 1 : 0

  load_balancer_arn = aws_lb.grafana.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}
