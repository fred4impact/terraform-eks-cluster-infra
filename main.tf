module "vpc" {
  source        = "./modules/vpc"
  region        = var.region
  cidr_block    = var.cidr_block
  env           = var.env
  project_name  = var.project_name
  key_pair_name = var.key_pair_name
  zone1         = var.zone1
  zone2         = var.zone2
  eks_name      = var.eks_name
}

module "eks" {
  source             = "./modules/eks"
  eks_name           = var.eks_name
  env                = var.env
  eks_version        = var.eks_version
  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id
}

module "alb_controller" {
  source                            = "./modules/alb-contorller"
  eks_cluster_name                  = module.eks.eks_cluster_name
  oidc_provider_arn                 = module.eks.oidc_provider_arn
  oidc_provider_url                 = module.eks.oidc_provider_url
  eks_cluster_certificate_authority = module.eks.eks_cluster_certificate_authority
  eks_cluster_endpoint              = module.eks.eks_cluster_endpoint
}
