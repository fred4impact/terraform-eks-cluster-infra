output "eks_cluster_name" {
  description = "The EKS cluster name."
  value       = aws_eks_cluster.eks.name
}

output "eks_cluster_endpoint" {
  description = "The EKS cluster endpoint."
  value       = aws_eks_cluster.eks.endpoint
}

output "oidc_provider_arn" {
  description = "The OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "The OIDC provider URL."
  value       = aws_iam_openid_connect_provider.this.url
}

output "eks_cluster_certificate_authority" {
  description = "The EKS cluster certificate authority data."
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}
