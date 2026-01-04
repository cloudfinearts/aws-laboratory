provider "aws" {
  default_tags {
    tags = local.tags
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.20.0"
    }

    helm = {
      source = "hashicorp/helm"
      # aws addons pins version due to breaking changes in 3.x
      version = ">= 2.9.0, < 3.0.0"
    }
  }

  required_version = ">= 1.4.2"
}

data "aws_caller_identity" "current" {}

locals {
  # enable karpenter to discover nodes and SG
  karpenter_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = {
    created-by = "eks-workshop-v2"
    env        = var.cluster_name
  }
}
