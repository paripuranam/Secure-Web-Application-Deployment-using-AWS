resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.project_name}-app"
  retention_in_days = 30
}
# WAF logs are handled within the WAF resource config itself in waf.tf
