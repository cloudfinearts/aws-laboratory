provider "aws" {
  region = "eu-central-1"
}

locals {
  name = "thanos-lab"
}

module "eks" {
  source = "./cluster"
  name   = local.name
}

data "aws_eks_cluster" "this" {
  name       = local.name
  depends_on = [module.eks]
}

# retrieve auth token
data "aws_eks_cluster_auth" "this" {
  name       = local.name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = "prometheus"
  }
}

# https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/eks/eks-oidc/README.md
