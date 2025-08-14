resource "aws_ecs_cluster" "this" {
  name = "retail-store"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
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
      },
      # enable OTEL
      {
        "name" : "JAVA_TOOL_OPTIONS",
        "value" : "-javaagent:/opt/aws-opentelemetry-agent.jar"
      },
      {
        "name" : "OTEL_JAVAAGENT_ENABLED",
        "value" : "true"
      },
      {
        "name" : "OTEL_EXPORTER_OTLP_ENDPOINT",
        "value" : "http://localhost:4317"
      },
      {
        "name" : "OTEL_EXPORTER_OTLP_INSECURE",
        "value" : "true"
      },
      {
        "name" : "OTEL_SERVICE_NAME",
        "value" : "ui-application"
      },
      {
        "name" : "OTEL_TRACES_EXPORTER",
        "value" : "otlp"
      },
      {
        "name" : "OTEL_METRICS_EXPORTER",
        "value" : "otlp"
      },
      {
        "name" : "OTEL_LOGS_EXPORTER",
        "value" : "none"
      },
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
    },
    # add container for ADOT
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = true

      portMappings = [{
        containerPort = 4317
        hostPort      = 4317
        protocol      = "tcp"
      }]

      # defaults from https://github.com/aws-observability/aws-otel-collector/blob/main/config/ecs/ecs-cloudwatch-xray.yaml
      command = ["--config=/etc/ecs/ecs-cloudwatch-xray.yaml"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.task.name
          awslogs-region        = data.aws_region.this.name
          awslogs-stream-prefix = "aws-otel-collector"
        }
      }
    },
  ])
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
  task_role_arn      = aws_iam_role.task.arn

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
  task_role_arn      = aws_iam_role.task.arn

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

    environment = [
      {
        name  = "DB_NAME"
        value = aws_db_instance.catalog.db_name
      },
      # enable OTEL
      {
        "name" : "JAVA_TOOL_OPTIONS",
        "value" : "-javaagent:/opt/aws-opentelemetry-agent.jar"
      },
      {
        "name" : "OTEL_JAVAAGENT_ENABLED",
        "value" : "true"
      },
      {
        "name" : "OTEL_EXPORTER_OTLP_ENDPOINT",
        "value" : "http://localhost:4317"
      },
      {
        "name" : "OTEL_EXPORTER_OTLP_INSECURE",
        "value" : "true"
      },
      {
        "name" : "OTEL_SERVICE_NAME",
        "value" : "catalog-application"
      },
      {
        "name" : "OTEL_TRACES_EXPORTER",
        "value" : "otlp"
      },
      {
        "name" : "OTEL_METRICS_EXPORTER",
        "value" : "otlp"
      },
      {
        "name" : "OTEL_LOGS_EXPORTER",
        "value" : "none"
      },
    ]

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
    },
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = true

      portMappings = [{
        containerPort = 4317
        hostPort      = 4317
        protocol      = "tcp"
      }]

      # defaults from https://github.com/aws-observability/aws-otel-collector/blob/main/config/ecs/ecs-cloudwatch-xray.yaml
      command = ["--config=/etc/ecs/ecs-cloudwatch-xray.yaml"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.task.name
          awslogs-region        = data.aws_region.this.name
          awslogs-stream-prefix = "aws-otel-collector"
        }
      }
    }
  ])
}

