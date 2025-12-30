# locals {
#   lbc_chart_version = "1.13.4"
# }

# resource "aws_route53_zone" "retail" {
#   name = "retailstore.com"
#   vpc {
#     vpc_id = module.vpc.vpc_id
#   }
# }

# https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/

# module "eks_blueprints_lbc" {
#   source  = "aws-ia/eks-blueprints-addons/aws"
#   version = "1.22.0"

#   cluster_name      = module.eks.cluster_name
#   cluster_endpoint  = module.eks.cluster_endpoint
#   cluster_version   = module.eks.cluster_version
#   oidc_provider_arn = module.eks.oidc_provider_arn

#   # create IRSA for LBC
#   enable_aws_load_balancer_controller = true
#   aws_load_balancer_controller = {
#     role_name   = "${module.eks.cluster_name}-alb-controller"
#     policy_name = "${module.eks.cluster_name}-alb-controller"
#   }

#   # apply chart yourself
#   create_kubernetes_resources = false
#   observability_tag           = null
# }

# module "eks_blueprints_external_dns" {
#   source  = "aws-ia/eks-blueprints-addons/aws"
#   version = "1.22.0"

#   cluster_name      = module.eks.cluster_name
#   cluster_endpoint  = module.eks.cluster_endpoint
#   cluster_version   = module.eks.cluster_version
#   oidc_provider_arn = module.eks.oidc_provider_arn

#   # create IAM roles and policies for external DNS
#   enable_external_dns = true
#   # sets resources in IAM role
#   external_dns_route53_zone_arns = [aws_route53_zone.retail.arn]
#   external_dns = {
#     create_role = true
#     role_name   = "${module.eks.cluster_name}-external-dns"
#     policy_name = "${module.eks.cluster_name}-external-dns"
#   }

#   create_kubernetes_resources = false
#   observability_tag           = null
# }

# output "albc" {
#   value = module.eks_blueprints_lbc.aws_load_balancer_controller
# }

# output "external_dns" {
#   value = module.eks_blueprints_external_dns.external_dns
# }
