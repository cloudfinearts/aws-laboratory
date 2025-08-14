data "aws_iam_policy_document" "ecs_exec" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:ExecuteCommand",
      "ecs:DescribeTasks"
    ]
    resources = [
      "${aws_ecs_cluster.this.arn}",
      # tasks ARNs
      "arn:aws:ecs:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:task/${aws_ecs_cluster.this.name}/*"
    ]
  }
}

# ECS exec works outside AWS without setting up SG, SSH keys
# misleading error about not running agent when connecting to stopped task!
resource "aws_iam_user_policy" "name" {
  name   = "SecureShellToEcsTasks"
  policy = data.aws_iam_policy_document.ecs_exec.json
  user   = "zerojoe"
}
