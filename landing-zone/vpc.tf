locals {
  public_subnets  = 3
  private_subnets = 3
}

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "landing-zone-vpc" }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count             = local.public_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 100)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  # enable for bastion
  #map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

resource "aws_subnet" "private" {
  count  = local.private_subnets
  vpc_id = aws_vpc.main.id
  # newbits are added to prefix
  # netnum is a decimal encoded to newbits portion to create subnets (max value is newbits range, e.g. 4 bits => 15)
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags                    = { Name = "private-subnet-${count.index}" }
}

# required fot NAT gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

# test connectivity using bastion node and SSH agent forwarding
# https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-scenarios.html
resource "aws_nat_gateway" "nat" {
  connectivity_type = "public"
  allocation_id     = aws_eip.nat.id
  # WARNING, located in public subnet
  subnet_id = aws_subnet.public[0].id
  tags      = { Name = "nat-gateway" }

  # requires IGW to create
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "public" {
  count          = local.public_subnets
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
  # external appliance for VPN inbound traffic, do not use
  #gateway_id = "123"
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private" {
  count          = local.private_subnets
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.nat.id
  destination_cidr_block = "0.0.0.0/0"
}
