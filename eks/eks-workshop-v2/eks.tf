locals {
  remote_node_cidr = var.remote_network_cidr
  remote_pod_cidr  = var.remote_pod_cidr
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                                     = var.cluster_name
  kubernetes_version                       = var.cluster_version
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  # grant access for AWS console
  access_entries = {
    "myuser" = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/myuser"
      policy_associations = {
        "AmazonEKSClusterAdminPolicy" = {
          access_scope = {
            type = "cluster"
          }
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        }
      }
    }
  }

  # supports only coredns, kube-proxy, vpc-cni and aws-ebs-csi-driver
  # enable other addons using terraform blueprints
  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
        enableNetworkPolicy = "true"
      })
    },
    coredns    = {},
    kube-proxy = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_security_group      = false
  create_node_security_group = false

  security_group_additional_rules = {
    hybrid-node = {
      cidr_blocks = [local.remote_node_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }

    hybrid-pod = {
      cidr_blocks = [local.remote_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  node_security_group_additional_rules = {
    hybrid_node_rule = {
      cidr_blocks = [local.remote_node_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }

    hybrid_pod_rule = {
      cidr_blocks = [local.remote_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  remote_network_config = {
    remote_node_networks = {
      cidrs = [local.remote_node_cidr]
    }
    # Required if running webhooks on Hybrid nodes
    remote_pod_networks = {
      cidrs = [local.remote_pod_cidr]
    }
  }

  eks_managed_node_groups = {
    default = {
      # m5.large
      instance_types           = ["t3.medium"]
      force_update_version     = true
      release_version          = var.ami_release_version
      use_name_prefix          = false
      iam_role_name            = "${var.cluster_name}-ng-default"
      iam_role_use_name_prefix = false

      # enable AWS LBC to use IMDSv2
      metadata_options = {
        http_put_response_hop_limit = 2
      }

      # warning, MNG does NOT scale backing ASG automatically!! Use CA or Karpenter
      # however, when upgrading AMI, MNG can temporarily scale past max limit to respect max unavailable
      # use MNG only for karpenter and have karpenter manage node pools without ASG
      min_size     = 1
      max_size     = 3
      desired_size = 1

      update_config = {
        max_unavailable_percentage = 50
      }

      labels = {
        workshop-default = "yes"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}
