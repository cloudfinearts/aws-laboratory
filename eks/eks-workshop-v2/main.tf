provider "aws" {
  default_tags {
    tags = local.tags
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67.0"
    }
  }

  required_version = ">= 1.4.2"
}

data "aws_caller_identity" "current" {}

locals {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.cluster_name
  }
}
