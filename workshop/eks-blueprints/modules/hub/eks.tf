data "aws_iam_session_context" "current" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.current.arn
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

locals {
  context_prefix  = var.project_context_prefix
  name            = "hub-cluster"
  region          = data.aws_region.current.id
  cluster_version = var.kubernetes_version
  enable_irsa     = var.enable_irsa

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  authentication_mode = var.authentication_mode
  eks_admin_role      = "WSParticipantRole"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-samples/eks-blueprints-for-terraform-workshop"
  }
}


data "aws_iam_policy_document" "eks_admin_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  assume_role_policy = data.aws_iam_policy_document.eks_admin_assume.json
  name               = local.eks_admin_role
}


################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.34.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  authentication_mode = local.authentication_mode

  enable_irsa = local.enable_irsa

  # Combine root account, current user/role and additional roles to be able to access the cluster KMS key - required for terraform updates
  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  enable_cluster_creator_admin_permissions = true

  # grant access to kubernetes API, not console
  access_entries = {
    # One access entry with a policy associated
    eks_admin = {
      principal_arn = aws_iam_role.eks_admin.arn
      policy_associations = {
        argocd = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnets


  # EKS auto mode, AWS manages and scales node (Fargate only), a host of limitations e.g. no spot, no daemonset etc.
  # cluster_compute_config = {
  #   enabled    = true
  #   node_pools = ["general-purpose", "system"]
  # }

  # provide defaults for all node groups
  # eks_managed_node_group_defaults = {
  #   instance_types = ["m5.large"]
  # }

  eks_managed_node_groups = {
    # matches resource aws_eks_node_group, module documentation states "any" for a type
    default = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = local.tags
}
