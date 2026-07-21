resource "aws_secretsmanager_secret" "grafana_admin" {
  name                    = "dropmong/aws-dev/monitoring/grafana-admin"
  description             = "AWS dev Grafana break-glass administrator credentials"
  recovery_window_in_days = 7

  tags = {
    Name      = "dropmong/aws-dev/monitoring/grafana-admin"
    Component = "monitoring"
    Purpose   = "break-glass-admin"
  }
}
