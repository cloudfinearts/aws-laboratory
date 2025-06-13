resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.ui.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# automatically creates Cloudwatch alarms for low and high (scale out), they will trigger this scaling policy
# dimension is automatically managed to keep close to target value
resource "aws_appautoscaling_policy" "ecs" {
  name               = "ui-scaling-policy"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = 1500
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.this.arn_suffix}/${aws_lb_target_group.this.arn_suffix}"
    }
  }
}
