# create IAM role, IAM policy, cloudwatch rules, SQS queues, access entry, EKS pod identity mapping
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
  namespace = helm_release.karpenter.namespace
  wait      = false

  # flag --set does not support maps
  # https://helm.sh/docs/intro/using_helm/#the-format-and-limitations-of---set
  # set = [{
  #   name = "nodeClass.subnetSelector.tags"
  #   value = jsonencode(local.karpenter_tags)
  # }]

  values = [
    <<EOT
nodePool:
  name: karpenter-np
nodeClass:
  role: ${module.karpenter.node_iam_role_name}
  selectorTags:
    %{~for name, value in local.karpenter_tags~}
    ${name}: "${value}"
    %{endfor}
EOT
  ]
}

