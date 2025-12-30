provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

locals {
  argocd_namespace = "argocd"
  environment      = "dev"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
  }
}

# bridge between IaC and k8s manifests
# creates secret matching cluster name? with tags and annotation (specific to created cloud resources) to be used by helm charts
module "gitops_bridge_bootstrap" {
  source  = "gitops-bridge-dev/gitops-bridge/helm"
  version = "0.1.0"
  cluster = {
    cluster_name = module.eks.cluster_name
    environment  = local.environment
    #enableannotation metadata     = local.annotations
    #enableaddons addons       = local.addons
  }

  #enableapps apps = local.argocd_apps
  argocd = {
    name             = "argocd"
    namespace        = local.argocd_namespace
    chart_version    = "7.8.13"
    values           = [file("${path.module}/argocd-initial-values.yaml")]
    timeout          = 600
    create_namespace = false
  }
}

