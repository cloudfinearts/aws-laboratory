variable "name" {
  type = string
}

data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_ec2_tag" "cluster" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  # associate resources created outside the cluster for AWS LBC, EBS CSI
  key = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
  # shared by multiple clusters, do not delete when cluster is deleted
  value = "shared"
}

resource "aws_ec2_tag" "elb" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  # auto discover subnets for public LB
  key   = "kubernetes.io/role/elb"
  value = "1"
}

# addons (coredns, kube-proxy etc.) are added by default, updating cluster does not update add-ons
resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  # EKS requires these to manage infrastructure such as security groups
  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.vpcResourceController
  ]
}

resource "aws_eks_node_group" "this" {
  cluster_name  = aws_eks_cluster.this.name
  node_role_arn = aws_iam_role.node.arn
  subnet_ids    = data.aws_subnets.default.ids
  capacity_type = "SPOT"
  # 2 cpu 8 GB, default is t3.medium (2 cpu, 4GB)
  instance_types  = ["m5.large"]
  node_group_name = "${var.name}-ng"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.workerNode,
    aws_iam_role_policy_attachment.cniPolicy,
    aws_iam_role_policy_attachment.containerRegistry
  ]
}

# IRSA TODO
# https://medium.com/@tech_18484/step-by-step-guide-creating-an-eks-cluster-with-terraform-resources-iam-roles-for-service-df1c5e389811
# data "tls_certificate" "eks" {
#   url = aws_eks_cluster.demo.identity[0].oidc[0].issuer
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   url             = aws_eks_cluster.demo.identity[0].oidc[0].issuer
# }
