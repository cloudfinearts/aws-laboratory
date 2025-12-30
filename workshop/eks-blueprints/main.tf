provider "aws" {
  region = "eu-central-1"
}

locals {
  project        = "eks-blueprints"
  eks_admin_role = "WSParticipantRole"
}

# host OSS git server on EC2 instance, I'll use github instead
# module "gitea" {
#   source  = "./modules/gitea"
#   project = local.project
# }

# output "gitea" {
#   value = module.gitea
# }

module "hub" {
  source           = "./modules/hub"
  addons           = {}
  environment_name = "${local.project}-dev"
}

output "hub" {
  value = module.hub
}

