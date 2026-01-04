resource "aws_vpc" "cloud" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    "Name" = "Cloud VPC"
  }
}

data "aws_availability_zones" "cloud" {
}

resource "aws_subnet" "cloud" {
  vpc_id                  = aws_vpc.cloud.id
  availability_zone       = data.aws_availability_zones.cloud.names[0]
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Cloud Subnet"
  }
}

resource "aws_route_table" "cloud" {
  vpc_id = aws_vpc.cloud.id
  # update static routes (CIDR block) with routes learnt from connected network
  propagating_vgws = [aws_vpn_gateway.vpn.id]
}


resource "aws_internet_gateway" "cloud" {
  vpc_id = aws_vpc.cloud.id
}

resource "aws_route" "cloud" {
  route_table_id         = aws_route_table.cloud.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cloud.id
}

resource "aws_route_table_association" "cloud" {
  route_table_id = aws_route_table.cloud.id
  subnet_id      = aws_subnet.cloud.id
}

resource "aws_security_group" "cloud" {
  vpc_id = aws_vpc.cloud.id
}

resource "aws_vpc_security_group_ingress_rule" "cloud_ssh" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.cloud.id
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "cloud" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.cloud.id
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_ami" "cloud" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "description"
    values = ["Amazon Linux 2023*kernel-6.1"]
  }
}

resource "aws_instance" "cloud" {
  associate_public_ip_address = true
  key_name                    = "mykey"
  subnet_id                   = aws_subnet.cloud.id
  ami                         = data.aws_ami.cloud.image_id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.cloud.id]
}

output "cloud_dns" {
  value = aws_instance.cloud.public_dns
}
