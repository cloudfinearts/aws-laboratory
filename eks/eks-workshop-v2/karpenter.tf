# create IAM role, IAM policy, cloudwatch rules, SQS queues, access entry
module "karpenter" {
  source                          = "terraform-aws-modules/eks/aws//modules/karpenter"
  cluster_name                    = module.eks.cluster_name
  namespace                       = "karpenter"
  service_account                 = "karpenter"
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  # OCI repo cannot be added as a helm repo
  # https://charts.karpenter.sh is outdated
  chart            = "oci://public.ecr.aws/karpenter/karpenter"
  name             = "karpenter"
  version          = "1.8.1"
  create_namespace = true
  namespace        = "karpenter"
  wait             = false
  skip_crds        = false

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    controller:
      resources:
        requests:
          cpu: 1
          memory: 1Gi
        limits:
          cpu: 1
          memory: 1Gi
    # eks pod identity does not require the annotation
    # serviceAccount:
    #   annotations:
    #     eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    nodeSelector:
        karpenter-controller: "yes"
    EOT
  ]
}

resource "helm_release" "nodepool" {
  chart     = "./manifests/charts/nodepool"
  name      = "nodepool"
  namespace = "karpenter"
  wait      = false

  values = [
    <<-EOT
    node_class:
      role: ${module.karpenter.node_iam_role_name}
    node_pool:
      name: karpenter-np
    EOT
  ]
}

