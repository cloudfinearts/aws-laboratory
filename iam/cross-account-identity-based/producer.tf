# https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies-cross-account-resource-access.html

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "this" {
}

# shared resource
resource "aws_s3_bucket" "this" {
  bucket        = "shared-bucket-${data.aws_caller_identity.this.account_id}"
  force_destroy = true
}

resource "aws_s3_object" "sample" {
  bucket  = aws_s3_bucket.this.bucket
  key     = "shared-file.txt"
  content = "Secret plan to crush competitors"
}

locals {
  # security account
  consumer_account_id = "647107203699"
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "AWS"
      # allow both user and role or be specific role/RoleName
      identifiers = ["arn:aws:iam::${local.consumer_account_id}:root"]
    }
  }
}

# to be assumed by consumer
resource "aws_iam_role" "producer" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "ConsumerS3Access"
}

data "aws_iam_policy_document" "s3" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "name" {
  role   = aws_iam_role.producer.name
  policy = data.aws_iam_policy_document.s3.json
}

output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "consumerAssumeRole" {
  value = aws_iam_role.producer.arn
}

output "producer" {
  value = data.aws_caller_identity.this.arn
}

