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

    environment = [
      {
        name  = "RETAIL_UI_BANNER"
        value = "Hola! Que tal?"
      },
      {
        name  = "ENDPOINTS_ASSETS"
        value = "http://assets"
      },
      {
        name  = "ENDPOINTS_CATALOG"
        value = "http://catalog"
      }
    ]

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
        awslogs-region        = data.aws_region.this.name
        awslogs-stream-prefix = "ui-service"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "assets" {
  family                   = "retail-store-ecs-assets"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  execution_role_arn = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name  = "assets"
    image = "public.ecr.aws/aws-containers/retail-store-sample-assets:0.7.0"

    portMappings = [{
      name          = "application"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    essential = true

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health.html || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task.name
        awslogs-region        = data.aws_region.this.name
        awslogs-stream-prefix = "assets-service"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "catalog" {
  family                   = "retail-store-ecs-catalog"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  execution_role_arn = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name  = "catalog"
    image = "public.ecr.aws/aws-containers/retail-store-sample-catalog:0.7.0"

    portMappings = [{
      name          = "application"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    environment = [{
      name  = "DB_NAME"
      value = aws_db_instance.catalog.db_name
    }]

    secrets = [
      {
        name : "DB_USER",
        valueFrom : "${aws_db_instance.catalog.master_user_secret[0].secret_arn}:username::"
      },
      {
        name : "DB_PASSWORD",
        # AWS supports access to json field in task def using ARN
        valueFrom : "${aws_db_instance.catalog.master_user_secret[0].secret_arn}:password::"
      },
      {
        name : "DB_ENDPOINT",
        valueFrom : format("arn:aws:ssm:%s:%s:parameter%s", data.aws_region.this.name, data.aws_caller_identity.this.account_id, aws_ssm_parameter.endpoint.name)
      }
    ]

    essential = true

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task.name
        awslogs-region        = data.aws_region.this.name
        awslogs-stream-prefix = "catalog-service"
      }
    }
  }])
}

