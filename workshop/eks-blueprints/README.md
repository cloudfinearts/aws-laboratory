# EKS blueprints workshop
https://github.com/aws-samples/eks-blueprints-for-terraform-workshop/tree/mainline

Created by Codebuild project
secrets=$(aws secretsmanager list-secrets --filters=Key=name,Values=eks-blueprints-workshop --query="SecretList[*].Name" --output text)
for s in $secrets; do aws secretsmanager delete-secret --secret-id $s --force-delete-without-recovery; done

IDE node scripts
gitea_credentials
argocd_hub_credentials

query path with reserved chars, use javascript style
'.data["admin.password"]'

## ArgoCD
k get secret -n argocd argocd-initial-admin-secret -o json |jq -r .data.password|base64 -d -

argocd login ab04c3a77b4474ed9930f0ae1f52f04e-1095955730.eu-central-1.elb.amazonaws.com --username admin
argocd repo add https://github.com/cloudfinearts/eks-blueprints-for-terraform-workshop.git

## GitOps Bridge
TF module for gitops bridge pattern does not receive many updates. It lacks in documentation and flux support is unclear.
Good for an inspiration how to deploy argo and addons along created k8s cluster. 