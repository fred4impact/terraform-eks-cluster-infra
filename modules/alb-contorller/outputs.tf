output "alb_controller_iam_role_arn" {
  description = "The ARN of the ALB controller IAM role."
  value       = aws_iam_role.aws_load_balancer_controller.arn
}
