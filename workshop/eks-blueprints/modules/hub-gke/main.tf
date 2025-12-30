provider "kubernetes" {
  # private nodes setting will mess up host and CA read from data source
  host                   = format("https://%s", data.google_container_cluster.this.endpoint)
  token                  = data.google_client_config.this.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.this.endpoint}"
    token                  = data.google_client_config.this.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

locals {
  argocd_namespace = "argocd"
}

module "gke" {
  source       = "../../../../../gcp-laboratory/modules/gke"
  cluster_name = var.cluster_name
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
  }
}

# bridge between IaC and k8s manifests => create both infra and gitops operator (or any support workloads) with IaC
# in other words, bootstrap argocd in the cluster
module "gitops_bridge_bootstrap" {
  source  = "gitops-bridge-dev/gitops-bridge/helm"
  version = "0.1.0"
  # create secret with cluster name to represent a cluster for workloads
  cluster = {
    cluster_name = data.google_container_cluster.this.name
    environment  = var.environment
    #enableannotation metadata     = local.annotations
    # set labels on the cluster in argocd Clusters
    addons = {
      fleet_member = "hub"
      # this label will trigger creation of ApplicationSet with prom stack
      # https://github.com/gitops-bridge-dev/gitops-bridge-argocd-control-plane-template/blob/main/bootstrap/control-plane/addons/oss/addons-kube-prometheus-stack-appset.yaml#L24
      enable_kube_prometheus_stack = true
    }
  }

  # deploy additional argo apps
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

