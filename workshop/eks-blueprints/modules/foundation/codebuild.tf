data "local_file" "spec" {
  filename = "${path.module}/buildspec.yaml"
}

data "aws_secretsmanager_secret_version" "ide" {
  secret_id = aws_secretsmanager_secret.ide.id

  depends_on = [aws_secretsmanager_secret_version.ide]
}

data "aws_iam_policy_document" "cb" {
  # statement {
  #   actions = [
  #     "codebuild:BatchPutCodeCoverages",
  #     "codebuild:BatchPutTestCases",
  #     "codebuild:CreateReport",
  #     "codebuild:CreateReportGroup",
  #     "codebuild:UpdateReport"
  #   ]
  #   effect = "Allow"
  #   resources = [
  #     format("arn:aws:codebuild:%s:%s:report-group/%s-*",
  #       data.aws_region.current.name,
  #       data.aws_caller_identity.current.account_id,
  #       aws_codebuild_project.this.name
  #     )
  #   ]
  # }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      # The policy failed "legacy parsing" when missing region and account id in ARN
      format("arn:aws:logs:%s:%s:log-group:/aws/codebuild/%s:*", data.aws_region.current.region, data.aws_caller_identity.current.account_id, aws_codebuild_project.this.name),
      format("arn:aws:logs:%s:%s:log-group:/aws/codebuild/%s", data.aws_region.current.region, data.aws_caller_identity.current.account_id, aws_codebuild_project.this.name),
    ]
  }

  statement {
    actions = [
      "ssm:PutParameter",
      # o||o
      #  ww
      # SSM document timeouts when GetParameter restricted
      # "ssm:GetParameter"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:*:parameter/*"
    ]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:HeadObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.this.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.this.bucket}/*"
    ]
  }

  statement {
    actions   = ["iam:GetRole"]
    effect    = "Allow"
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.cb.name}"]
  }

  # terraform requires many actions to create and read secrets
  statement {
    actions = [
      "secretsmanager:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cb_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "codebuild.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "cb" {
  assume_role_policy = data.aws_iam_policy_document.cb_assume.json
  name               = "${var.project}-cb"
}

resource "aws_iam_role_policy" "cb" {
  policy = data.aws_iam_policy_document.cb.json
  role   = aws_iam_role.cb.name
}

resource "aws_codebuild_project" "this" {
  name         = "${var.project}-deploy"
  service_role = aws_iam_role.cb.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  cache {
    type = "NO_CACHE"
  }
  # actual key is fully qualified
  #encryption_key = "alias/aws/s3"

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    image_pull_credentials_type = "CODEBUILD"
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "TFSTATE_BUCKET_NAME"
      type  = "PLAINTEXT"
      value = aws_s3_bucket.this.bucket
    }

    environment_variable {
      name  = "WORKSHOP_GIT_URL"
      type  = "PLAINTEXT"
      value = "https://github.com/aws-samples/eks-blueprints-for-terraform-workshop"
    }

    environment_variable {
      name  = "WORKSHOP_GIT_BRANCH"
      type  = "PLAINTEXT"
      value = "mainline"
    }

    environment_variable {
      name  = "FORCE_DELETE_VPC"
      type  = "PLAINTEXT"
      value = "true"
    }

    environment_variable {
      name  = "GITEA_PASSWORD"
      type  = "PLAINTEXT"
      value = replace(split(":", data.aws_secretsmanager_secret_version.ide.secret_string)[1], "\"", "")
    }

    environment_variable {
      name  = "IS_WS"
      type  = "PLAINTEXT"
      value = "false"
    }
  }

  # typically git repo
  source {
    type      = "NO_SOURCE"
    buildspec = data.local_file.spec.content
  }
  build_timeout = 10
}

