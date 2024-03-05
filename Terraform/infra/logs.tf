resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 365
  skip_destroy      = var.cloudwatch_skip_destroy
}
