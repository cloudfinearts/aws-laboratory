resource "aws_security_group" "lb" {
  name   = "lb-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "lb" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.lb.id
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "tls" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.lb.id
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lb" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_lb" "this" {
  name               = "retail-store-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = module.vpc.public_subnets
  internal           = false
  idle_timeout       = 60
}

# ECS service automatically registers tasks in TG
resource "aws_lb_target_group" "this" {
  name                 = "retail-store-tg"
  protocol             = "HTTP"
  port                 = 8080
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    enabled  = true
    interval = 30
    path     = "/actuator/health"
    # use the same port as TG
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
  }
}

# listener associates LB with TG
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }


  # default_action {
  #   type = "redirect"

  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}
