provider "aws" {
  region = "eu-central-1"
}

locals {
  name = "thanos-lab"
}

# retrieve auth token
data "aws_eks_cluster_auth" "this" {
  name       = local.name
  depends_on = [aws_eks_cluster.this]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = "prometheus"
  }
}
