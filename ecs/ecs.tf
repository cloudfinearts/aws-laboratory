resource "aws_ecs_cluster" "this" {
  name = "retail-store"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

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
      # channel are used for session communication
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    effect    = "Allow"
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

# allow ECS agent to access AWS api, e.g. pulling images, writing logs
resource "aws_iam_role" "task_execution" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "retailStoreEcsTaskExecutionRole"
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  # use ECR, Cloudwatch etc.
  # arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution.name
}

resource "aws_iam_role_policy_attachment" "tax_execution_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.task_execution.name
}

data "aws_region" "current" {
}

resource "aws_cloudwatch_log_group" "task" {
  name = "retail-store-ecs-tasks"
}

# task is immutable, a change creates new revision
resource "aws_ecs_task_definition" "ui" {
  # family and revision represents task name
  family = "retail-store-ecs-ui"
  # docker networking
  network_mode = "awsvpc"
  # execution env
  requires_compatibilities = ["FARGATE"]
  # cpu units for fargate
  cpu    = "1024"
  memory = "2048"

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  # ECS agent
  execution_role_arn = aws_iam_role.task_execution.arn
  # container
  task_role_arn = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "retailStore"
    image = "public.ecr.aws/aws-containers/retail-store-sample-ui:0.7.0"

    portMappings = [{
      name          = "application"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    environment = [{
      name  = "RETAIL_UI_BANNER"
      value = "Hola! Que tal?"
    }]

    essential = true

    linuxParameters = {
      initProcessEnabled = true
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ui-service"
      }
    }
  }])
}

resource "aws_security_group" "service" {
  name   = "retail-store-ecs-service"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "service" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "service" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.service.id
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_ecs_service" "this" {
  name            = "ui"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  # wait forever if container fails to register in TG
  wait_for_steady_state = true
  # enable ECS Exec
  # Fargate includes SSM agent by default
  enable_execute_command = true

  # ECS service-linked role used by default if exists, not required for awsvpc
  #iam_role = "value"

  load_balancer {
    # register task in TG
    target_group_arn = aws_lb_target_group.this.arn
    # expose port
    container_name = "retailStore"
    container_port = 8080
  }

  network_configuration {
    # distribute tasks across azs
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  # using app autoscaling
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
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

