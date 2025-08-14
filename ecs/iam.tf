data "aws_iam_policy_document" "trust" {
  statement {
    sid = "AllowEcsAssumeRole"
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task" {
  statement {
    actions = [
      # required by ECS exec
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "otel" {
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "ssm:GetParameters"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "task" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "retailStoreEcsTaskRole"
}

resource "aws_iam_role_policy" "task" {
  name   = "SecureShellBetweenEcsAndSessionManager"
  policy = data.aws_iam_policy_document.task.json
  role   = aws_iam_role.task.name
}

resource "aws_iam_role_policy" "otel" {
  policy = data.aws_iam_policy_document.otel.json
  role   = aws_iam_role.task.name
  name   = "AWSOpenTelemetryPolicy"
}

# allow ECS agent to access AWS api, e.g. pulling images, writing logs
resource "aws_iam_role" "task_execution" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "retailStoreEcsTaskExecutionRole"
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  # use ECR, Cloudwatch etc.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution.name
}

resource "aws_iam_role_policy_attachment" "tax_execution_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.task_execution.name
}

data "aws_iam_policy_document" "execution" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.catalog.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "execution" {
  policy = data.aws_iam_policy_document.execution.json
  role   = aws_iam_role.task_execution.name
}
