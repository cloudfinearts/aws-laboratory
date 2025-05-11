provider "aws" {
  region = "eu-central-1"
  # assume role for another account
  profile = "security"
  alias   = "security"
}

data "aws_caller_identity" "dest" {
  provider = aws.security
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "description"
    values = ["Amazon Linux 2 Kernel 5.10*"]
  }
}

# account shown in ARN and Owner field
resource "aws_instance" "this" {
  provider      = aws.security
  instance_type = "t2.micro"
  ami           = data.aws_ami.ami.image_id
  tags = {
    "Name" = "node-account-${data.aws_caller_identity.dest.account_id}"
  }
}
