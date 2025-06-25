output "vpc_id" {
  description = "The VPC ID."
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "The EKS cluster name."
  value       = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "The EKS cluster endpoint."
  value       = module.eks.eks_cluster_endpoint
}

output "oidc_provider_arn" {
  description = "The OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "The OIDC provider URL."
  value       = module.eks.oidc_provider_url
}

output "alb_controller_iam_role_arn" {
  description = "The ARN of the ALB controller IAM role."
  value       = module.alb_controller.alb_controller_iam_role_arn
}
