# https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies-cross-account-resource-access.html

provider "aws" {
  alias   = "security"
  region  = "eu-central-1"
  profile = "security"
}

resource "aws_iam_user" "consumer" {
  provider = aws.security
  name     = "acme"
  # path = "value"
}

resource "aws_iam_access_key" "consumer" {
  user     = aws_iam_user.consumer.name
  provider = aws.security
  # encrypt secret key in state file
  # pgp_key = "123"
}

resource "aws_secretsmanager_secret" "consumer" {
  provider = aws.security
  name     = "acme-user-credentials"
}

resource "aws_secretsmanager_secret_version" "consumer" {
  provider  = aws.security
  secret_id = aws_secretsmanager_secret.consumer.id
  secret_string = jsonencode({
    "access_key_id"     = aws_iam_access_key.consumer.id
    "secret_access_key" = aws_iam_access_key.consumer.secret
  })
}

data "aws_iam_policy_document" "consumer" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    # role to be assumed by consumer user
    resources = [aws_iam_role.producer.arn]
  }
}

resource "aws_iam_user_policy" "consumer" {
  provider = aws.security
  policy   = data.aws_iam_policy_document.consumer.json
  user     = aws_iam_user.consumer.name
}

output "consumer" {
  value = aws_iam_user.consumer.arn
}

output "consumer_cli_creds" {
  value = aws_secretsmanager_secret.consumer.arn
}

