variable "project" {
  type = string
}

resource "aws_s3_bucket" "this" {
  bucket        = format("%s-bucket", var.project)
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "glue.amazonaws.com"
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "ide" {
  name              = format("%s-ide", var.project)
  retention_in_days = 1
}

data "aws_iam_policy_document" "inline" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = [aws_cloudwatch_log_group.ide.arn]
  }

  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:CreateSecret"
    ]
    effect = "Allow"
    resources = [
      aws_secretsmanager_secret.ide.arn,
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:eks-blueprints-workshop-*"
    ]
  }
}

resource "aws_iam_role" "shared" {
  name               = format("%s-shared-role", var.project)
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.shared.name
}

# log ssm document output to cloudwatch
resource "aws_iam_role_policy_attachment" "cw" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.shared.name
}

resource "aws_iam_role_policy" "shared" {
  role   = aws_iam_role.shared.name
  policy = data.aws_iam_policy_document.inline.json
}
