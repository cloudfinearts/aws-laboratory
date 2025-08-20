# EKS workshop v2
https://github.com/aws-samples/eks-workshop-v2

## Errors
failed to fetch VPC ID from instance metadata
- aws load balancer pods
- when AMI requires IMDSv2, increase http hop limit 
- https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/#using-the-amazon-ec2-instance-metadata-server-version-2-imdsv2

## Gotcha
Destroying eks cluster did not remove LB and other resources created by AWS LBC. Make sure to delete LBC helm release prior.