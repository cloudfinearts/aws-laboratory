resource "aws_vpc" "onprem" {
  provider             = aws.onprem
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true

  tags = {
    "Name" = "On-prem VPC"
  }
}

data "aws_availability_zones" "onprem" {
  provider = aws.onprem
}

resource "aws_subnet" "onprem" {
  provider                = aws.onprem
  vpc_id                  = aws_vpc.onprem.id
  availability_zone       = data.aws_availability_zones.onprem.names[0]
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "On-prem Subnet"
  }
}

resource "aws_route_table" "onprem" {
  provider = aws.onprem
  vpc_id   = aws_vpc.onprem.id
}


resource "aws_internet_gateway" "onprem" {
  provider = aws.onprem
  vpc_id   = aws_vpc.onprem.id
}

resource "aws_route" "onprem" {
  provider               = aws.onprem
  route_table_id         = aws_route_table.onprem.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.onprem.id
}

resource "aws_route_table_association" "onprem" {
  provider       = aws.onprem
  route_table_id = aws_route_table.onprem.id
  subnet_id      = aws_subnet.onprem.id
}

resource "aws_security_group" "onprem" {
  provider = aws.onprem
  vpc_id   = aws_vpc.onprem.id
}

resource "aws_vpc_security_group_ingress_rule" "onprem_ssh" {
  provider          = aws.onprem
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.onprem.id
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "onprem_icmp" {
  provider          = aws.onprem
  ip_protocol       = "icmp"
  security_group_id = aws_security_group.onprem.id
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "onprem" {
  provider          = aws.onprem
  ip_protocol       = "-1"
  security_group_id = aws_security_group.onprem.id
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_ami" "onprem" {
  provider    = aws.onprem
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

resource "aws_key_pair" "onprem" {
  provider   = aws.onprem
  public_key = file("${path.module}/mykey.pub")
  key_name   = "mykey"
}

resource "aws_instance" "onprem" {
  provider                    = aws.onprem
  associate_public_ip_address = true
  key_name                    = aws_key_pair.onprem.key_name
  subnet_id                   = aws_subnet.onprem.id
  ami                         = data.aws_ami.onprem.image_id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.onprem.id]
  # accept traffic not destined for this instance
  source_dest_check = false

  # executed once during first boot
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y libreswan
EOF
}

output "onprem_vm" {
  value = aws_instance.onprem.public_dns
}
