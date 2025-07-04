provider "aws" {
  region = "eu-central-1"
}

locals {
  project = "eks-blueprints"
}

module "foundation" {
  source  = "./modules/foundation"
  project = local.project
}

# module "workshop" {
#   source = "./modules/workshop"
# }

output "all" {
  value = module.foundation
}


