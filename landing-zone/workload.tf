data "aws_ami" "ami" {
  most_recent = true

  owners = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "description"
    values = ["Amazon Linux 2 Kernel 5.10*"]
  }
}

resource "aws_iam_role" "ssm" {
  name = "SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# check SSM agent - sudo systemctl status amazon-ssm-agent.service
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.ssm.name
}

# register VM with SSM and log in without key via ssm-user
# SSM apis have to reachable via internet or VPC endpoint
# https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html
resource "aws_instance" "private" {
  # many AMI do not include SSM agent
  ami                         = "ami-0dac2efb38d54a859"
  instance_type               = "t2.micro"
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.private[0].id
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.private.id]
}

resource "aws_security_group" "private" {
  name   = "private-node-sg"
  vpc_id = aws_vpc.main.id
}

# resource "aws_vpc_security_group_ingress_rule" "private" {
#   ip_protocol                  = "-1"
#   security_group_id            = aws_security_group.private.id
#   referenced_security_group_id = aws_security_group.bastion.id
# }

# YEEEAAAAH, missing this critical bit to reach internet
resource "aws_vpc_security_group_egress_rule" "private" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.private.id
  cidr_ipv4         = "0.0.0.0/0"
}

output "node" {
  value = aws_instance.private.private_dns

}
