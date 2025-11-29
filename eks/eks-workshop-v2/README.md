# EKS workshop v2
https://github.com/aws-samples/eks-workshop-v2

hard to find manual
https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter

https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v21.8.0/examples/karpenter/main.tf

## EKS errors
failed to fetch VPC ID from instance metadata
- affects aws load balancer pods
- when AMI requires IMDSv2, increase http hop limit 
- https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/#using-the-amazon-ec2-instance-metadata-server-version-2-imdsv2

Destroying eks cluster did not remove LB and other resources created by AWS LBC. Make sure to delete LBC helm release prior.

## EKS Addons
https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-dns/

Weird, pretty much impossible to find available fields for external_dns field in the addon. Only Copilot provides a list (go struct) but google search comes empty handed

https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/blob/main/docs/addons/external-dns.md

## Karpenter
https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter

Validated karpenter
- pending pods will have nodes created
- topology spread contraint will spread pods over nodes
- empty pods will be recycled in 1min, system pods are ignored

### Karpenter bugs
karpenter pods print no logs, but fail on readiness/liveness probes
- add eks pod identity addon since IRSA was not setup

## EKS pod identity
https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html

Preferable over IRSA with some caveats.

How it works:
- install eks pod identity addon
    - pod will be created on each node to handle the process
- create IAM role for a workload, reference session tags passsed by eks pod identity to fine-tune
- create eks pod identity association on the cluster between IAM role, namespace and service account used by the pod
- create a pod with the service account
- eks pod identity will create env vars in the pod for assuming the role via SDK, CLI

IAM role can be reused across clusters without modification. Just create pod identity associations. Great advantage over IRSA requiring modifications to trust policy and annotating service accounts.

Fargate does not support it since Fargate cannot run DaemonSets.

EKS pod identity is part of AWS default credential provider chain. The chain stops on the first success getting access credentials.

Warning, pod identity currently does not support using static STS session name, making it useless for managed Kafka (MSK)!
