# EKS blueprints workshop
https://github.com/aws-samples/eks-blueprints-for-terraform-workshop/tree/mainline

Created by Codebuild project
secrets=$(aws secretsmanager list-secrets --filters=Key=name,Values=eks-blueprints-workshop --query="SecretList[*].Name" --output text)
for s in $secrets; do aws secretsmanager delete-secret --secret-id $s --force-delete-without-recovery; done