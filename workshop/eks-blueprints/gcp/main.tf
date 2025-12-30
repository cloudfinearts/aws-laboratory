provider "google" {
  region = "europe-central2"
}

locals {
  project = "eks-blueprints"
}

module "hub_gke" {
  source       = "../modules/hub-gke"
  cluster_name = local.project
  environment  = "dev"
}
