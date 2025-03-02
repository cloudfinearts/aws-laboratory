# resource "aws_security_group" "lb" {
#   vpc_id = data.aws_vpc.this.id
#   name   = "rds-lb-sg"
# }

# resource "aws_vpc_security_group_ingress_rule" "lb" {
#   ip_protocol       = "tcp"
#   security_group_id = aws_security_group.lb.id
#   from_port         = 5432
#   to_port           = 5432
#   cidr_ipv4         = "0.0.0.0/0"
# }

resource "aws_lb" "this" {
  load_balancer_type = "network"
  name               = "rds-proxy-lb"
  # works without SG
  #   security_groups    = [aws_security_group.lb.id]
  subnets = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  port     = 5432
  protocol = "TCP"
}

resource "aws_lb_target_group" "this" {
  name     = "rds-proxy-tg"
  port     = 5432
  protocol = "TCP"
  health_check {
    protocol = "TCP"
  }
  vpc_id = data.aws_vpc.this.id
  # target identified by IP address
  target_type = "ip"
}

// RDS proxy has got created VPC endpoint each with ENI
// No obvious identifier available for proxy
data "aws_network_interfaces" "this" {
  filter {
    name   = "group-id"
    values = [aws_security_group.proxy.id]
  }

  filter {
    name   = "interface-type"
    values = ["vpc_endpoint"]
  }
}

data "aws_network_interface" "this" {
  for_each = toset(data.aws_network_interfaces.this.ids)
  id       = each.value
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = data.aws_network_interface.this
  target_group_arn = aws_lb_target_group.this.arn
  // DNS is not supported
  target_id = each.value.private_ip
  port      = 5432
}

output "nlb" {
  value = aws_lb.this.dns_name
}
