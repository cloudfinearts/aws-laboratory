resource "aws_vpc" "this" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.this.names[0]
  cidr_block              = "192.168.0.0/16"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table_association" "this" {
  route_table_id = aws_route_table.this.id
  subnet_id      = aws_subnet.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "this" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_security_group" "ide" {
  vpc_id = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "this" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.ide.id
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.ide.id
  cidr_ipv4         = aws_vpc.this.cidr_block
  from_port         = 9999
  to_port           = 9999
  description       = "Gitea API from VPC"
}


resource "aws_vpc_security_group_ingress_rule" "ssh" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.ide.id
  cidr_ipv4         = aws_vpc.this.cidr_block
  from_port         = 2222
  to_port           = 2222
  description       = "Gitea SSH from VPC"
}

# a list of cidrs used by AWS for a service, the list can get updated over time
data "aws_ec2_managed_prefix_list" "cfr" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.global.cloudfront.origin-facing"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "cfr" {
  security_group_id = aws_security_group.ide.id
  description       = "HTTP from Cloudfront"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  # source cidrs
  prefix_list_id = data.aws_ec2_managed_prefix_list.cfr.id
}
