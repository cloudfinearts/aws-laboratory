resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-b"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-b"
  }
}

resource "aws_subnet" "tgw_b" {
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = "10.2.2.0/28"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "tgw-b"
  }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
}

resource "aws_route_table" "rt_b" {
  vpc_id = aws_vpc.vpc_b.id
}

resource "aws_route_table_association" "rta_b" {
  route_table_id = aws_route_table.rt_b.id
  subnet_id      = aws_subnet.subnet_b.id
}

resource "aws_route" "default_b" {
  route_table_id         = aws_route_table.rt_b.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_b.id
}

resource "aws_route" "vpc_b_to_a" {
  route_table_id         = aws_route_table.rt_b.id
  destination_cidr_block = aws_vpc.vpc_a.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

module "ssm_node_b" {
  source    = "../../modules/ssm-node"
  subnet_id = aws_subnet.subnet_b.id
  name      = "ssm-node-vpc-b"
}


resource "aws_vpc_security_group_ingress_rule" "icmp_b_from_a" {
  security_group_id = module.ssm_node_b.sg_id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = aws_vpc.vpc_a.cidr_block
}
