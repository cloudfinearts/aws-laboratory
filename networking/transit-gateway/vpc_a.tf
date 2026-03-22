resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-a"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-a"
  }
}

resource "aws_subnet" "tgw_a" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.1.2.0/28"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "tgw-a"
  }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
}

resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpc_a.id
}

resource "aws_route_table_association" "rta_a" {
  route_table_id = aws_route_table.rt_a.id
  subnet_id      = aws_subnet.subnet_a.id
}

resource "aws_route" "default_a" {
  route_table_id         = aws_route_table.rt_a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_a.id
}

resource "aws_route" "vpc_a_to_b" {
  route_table_id         = aws_route_table.rt_a.id
  destination_cidr_block = aws_vpc.vpc_b.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "vpc_a_to_c" {
  route_table_id         = aws_route_table.rt_a.id
  destination_cidr_block = aws_vpc.vpc_c.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

module "ssm_node_a" {
  source    = "../../modules/ssm-node"
  subnet_id = aws_subnet.subnet_a.id
  name      = "ssm-node-vpc-a"
}

resource "aws_vpc_security_group_ingress_rule" "icmp_a_from_b" {
  security_group_id = module.ssm_node_a.sg_id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = aws_vpc.vpc_b.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "icmp_a_from_c" {
  security_group_id = module.ssm_node_a.sg_id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = aws_vpc.vpc_c.cidr_block
}
