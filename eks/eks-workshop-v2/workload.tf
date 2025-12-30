provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# AWS LBC is an ingress controller
# resource "helm_release" "lbc" {
#   name             = "aws-lbc"
#   namespace        = "kube-system"
#   create_namespace = true

#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   version    = "1.13.4"

#   set {
#     name  = "clusterName"
#     value = module.eks.cluster_name
#   }

#   set {
#     name = "serviceAccount.name"
#     # SA not exposed by addon
#     value = "aws-load-balancer-controller-sa"
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.addons_ingress.lbc_config.iam_role_arn
#   }

#   depends_on = [module.eks]
# }
