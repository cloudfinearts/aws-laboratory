# FIXME if created after instance, misses generated notification, use SNS to trigger on past events
# event bridge is NOT cloudtrail!!
# trigger rule when AWS service generated an event matching the pattern, log to CW for debugging
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-instance-state-changes.html
resource "aws_cloudwatch_event_rule" "instance" {
  name = "instance-running"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      # reboot does not generate notification since it happens at os level
      state = ["running"]
      #instance-id = [aws_instance.this.id]
    }
  })
}

# see request in cloudtrail -> event history (90 days)
# search by event name or event source
# json request includes user identity, event name (StartBuild), request params (projectName) and full response
resource "aws_cloudwatch_event_target" "codebuild" {
  target_id = "StartCodeBuildOnInstanceRunning"
  # event source
  rule = aws_cloudwatch_event_rule.instance.name
  # target receives matched event, use transfomer to modify event format in order to pass e.g. env vars
  # https://docs.aws.amazon.com/codebuild/latest/APIReference/API_StartBuild.html#API_StartBuild_RequestSyntax
  arn      = aws_codebuild_project.this.arn
  role_arn = aws_iam_role.eventbridge.arn
}

resource "aws_iam_role" "eventbridge" {
  name = "eventbridge-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "eventbridge-codebuild-policy"
  role = aws_iam_role.eventbridge.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codebuild:StartBuild"
      Resource = aws_codebuild_project.this.arn
    }]
  })
}

# debug events sent to event bridge
# resource "aws_cloudwatch_log_group" "debug" {
#   name              = "/aws/events/debug"
#   retention_in_days = 1
# }

# # role arn is not supported in event target
# resource "aws_cloudwatch_log_resource_policy" "debug" {
#   policy_name = "eventbridge-debug-policy"
#   policy_document = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "events.amazonaws.com"
#       }
#       Action = [
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ]
#       Resource = "${aws_cloudwatch_log_group.debug.arn}:*"
#     }]
#   })
# }

# resource "aws_cloudwatch_event_rule" "debug" {
#   event_pattern = jsonencode({
#     source = ["aws.ec2"]
#   })
# }

# resource "aws_cloudwatch_event_target" "debug" {
#   rule = aws_cloudwatch_event_rule.debug.name
#   arn  = aws_cloudwatch_log_group.debug.arn
# }
