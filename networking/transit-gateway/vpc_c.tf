resource "aws_vpc" "vpc_c" {
  cidr_block           = "10.3.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-c"
  }
}

resource "aws_subnet" "subnet_c" {
  vpc_id                  = aws_vpc.vpc_c.id
  cidr_block              = "10.3.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-c"
  }
}

resource "aws_subnet" "tgw_c" {
  vpc_id            = aws_vpc.vpc_c.id
  cidr_block        = "10.3.2.0/28"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "tgw-c"
  }
}

resource "aws_internet_gateway" "igw_c" {
  vpc_id = aws_vpc.vpc_c.id
}

resource "aws_route_table" "rt_c" {
  vpc_id = aws_vpc.vpc_c.id
}

resource "aws_route_table_association" "rta_c" {
  route_table_id = aws_route_table.rt_c.id
  subnet_id      = aws_subnet.subnet_c.id
}

resource "aws_route" "default_c" {
  route_table_id         = aws_route_table.rt_c.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_c.id
}

resource "aws_route" "vpc_c_to_a" {
  route_table_id         = aws_route_table.rt_c.id
  destination_cidr_block = aws_vpc.vpc_a.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}


module "ssm_node_c" {
  source    = "../../modules/ssm-node"
  subnet_id = aws_subnet.subnet_c.id
  name      = "ssm-node-vpc-c"
}

resource "aws_vpc_security_group_ingress_rule" "icmp_c_from_a" {
  security_group_id = module.ssm_node_c.sg_id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = aws_vpc.vpc_a.cidr_block
}
