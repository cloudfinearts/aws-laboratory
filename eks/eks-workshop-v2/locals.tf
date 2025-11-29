data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.cluster_name
  }

  eks_cluster_endpoint      = module.eks.cluster_endpoint
  eks_cluster_version       = module.eks.cluster_version
  cluster_security_group_id = module.eks.cluster_security_group_id

  addon_context = {
    account_id                    = data.aws_caller_identity.current.account_id
    region_name                   = data.aws_region.current.region
    cluster_name                  = module.eks.cluster_name
    cluster_endpoint              = local.eks_cluster_endpoint
    cluster_version               = module.eks.cluster_version
    oidc_provider_arn             = module.eks.oidc_provider_arn
    vpc_id                        = module.vpc.vpc_id
    tags                          = {}
    irsa_iam_role_path            = "/"
    irsa_iam_permissions_boundary = ""
  }
}

