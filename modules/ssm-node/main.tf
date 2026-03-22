# data "aws_ami" "ami" {
#   most_recent = true

#   owners = ["amazon"]
#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }

#   # unstable, no guarantee SSM agent is included
#   filter {
#     name   = "description"
#     values = ["Amazon Linux 2023 AMI*x86_64 HVM kernel-6.1"]
#   }
# }

locals {
  # al2023-ami-2023.8.20250808.1-kernel-6.1-x86_64
  ami_id_ssm_agent = "ami-05a2d2d0a1020fecd"
}

resource "aws_iam_role" "ssm_node" {
  name_prefix = "SsmNodeRole-"

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

resource "aws_iam_role_policy_attachment" "ssm_node" {
  role       = aws_iam_role.ssm_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_node" {
  role = aws_iam_role.ssm_node.name
}

data "aws_subnet" "this" {
  id = var.subnet_id
}

resource "aws_security_group" "ssm_node" {
  name_prefix = "ssm-node-sg-"
  vpc_id      = data.aws_subnet.this.vpc_id

  tags = {
    Name = var.name
  }
}

resource "aws_vpc_security_group_egress_rule" "ssm_node" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.ssm_node.id
  cidr_ipv4         = "0.0.0.0/0"
}

# connect using session manager
resource "aws_instance" "ssm_node" {
  ami                    = local.ami_id_ssm_agent
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm_node.name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ssm_node.id]

  tags = {
    Name = var.name
  }
}

output "instance_id" {
  value = aws_instance.ssm_node.id
}

output "sg_id" {
  value = aws_security_group.ssm_node.id
}
