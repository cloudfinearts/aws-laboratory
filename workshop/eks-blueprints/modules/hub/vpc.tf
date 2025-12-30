locals {
  env            = var.environment_name
  vpc_cidr       = var.vpc_cidr
  num_of_subnets = min(length(data.aws_availability_zones.available.names), 3)
  azs            = slice(data.aws_availability_zones.available.names, 0, local.num_of_subnets)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0.0"

  name = local.env
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 6, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 6, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  # let TF manage default resources on created! VPC
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.env}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.env}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.env}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# output "vpc_id" {
#   description = "The ID of the VPC"
#   value       = module.vpc.vpc_id
# }

# output "private_subnets" {
#   description = "List of IDs of private subnets"
#   value       = module.vpc.private_subnets
# }

# output "vpc_name" {
#   description = "The ID of the VPC"
#   value       = local.env
# }
