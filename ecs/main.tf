provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "current" {
  state = "available"
}

data "aws_caller_identity" "this" {
}

data "aws_region" "this" {
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "retail-store-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.current.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    application = "retail-store"
  }
}
