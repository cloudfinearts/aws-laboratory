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

resource "aws_ecs_service" "ui" {
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

  # service discovery between services
  # inter-services TLS supports only AWS Private CA, can be costly
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.retailStore.name
    # multiple services allowed
    service {
      # service created in Cloud map linked to port name
      discovery_name = "ui"
      port_name      = "application"
      # alias used by other services
      client_alias {
        port     = 80
        dns_name = "ui"
      }
    }
  }

  # using app autoscaling
  lifecycle {
    ignore_changes = [desired_count]
  }
}

# namespace in aws cloud map
resource "aws_service_discovery_http_namespace" "retailStore" {
  name = "retailStore.local"
}

resource "aws_ecs_service" "assets" {
  name                  = "assets"
  cluster               = aws_ecs_cluster.this.arn
  task_definition       = aws_ecs_task_definition.assets.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  wait_for_steady_state = true

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.retailStore.name
    service {
      port_name      = "application"
      discovery_name = "assets"
      # service definition?
      client_alias {
        port     = 80
        dns_name = "assets"
      }
    }
  }
}

resource "aws_ecs_service" "catalog" {
  name                  = "catalog"
  cluster               = aws_ecs_cluster.this.arn
  task_definition       = aws_ecs_task_definition.catalog.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  wait_for_steady_state = true

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.retailStore.name
    service {
      port_name      = "application"
      discovery_name = "catalog"
      client_alias {
        port     = 80
        dns_name = "catalog"
      }
    }
    # envoy logs
    # ui service could not resolve catalog dns, got resolved by adding log config to ui service :)
    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.task.name
        awslogs-region        = data.aws_region.this.name
        awslogs-stream-prefix = "catalog-service-connect"
      }
    }
  }
}
