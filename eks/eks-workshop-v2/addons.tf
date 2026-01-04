module "addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.23.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true

  aws_load_balancer_controller = {
    chart_version = "1.14.1"
    role_name     = "${module.eks.cluster_name}-alb-controller"
    policy_name   = "${module.eks.cluster_name}-alb-controller"
    wait          = true
  }
  #   create_kubernetes_resources = false

  #   enable_external_dns = true
  #   # set resources in IAM role
  #   external_dns_route53_zone_arns = [aws_route53_zone.retail.arn]

  #   external_dns = {
  #     role_name   = "${module.eks.cluster_name}-external-dns"
  #     policy_name = "${module.eks.cluster_name}-external-dns"
  #     wait        = true
  #   }

  # disable cfn usage telemetry
  observability_tag = null
}

# resource "aws_route53_zone" "retail" {
#   name = "retailstore.com"
#   vpc {
#     # resolve within VPC => private zone
#     vpc_id = module.vpc.vpc_id
#   }
# }
