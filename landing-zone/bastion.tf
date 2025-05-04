# resource "aws_key_pair" "main" {
#   public_key = file(pathexpand("~/.ssh/mykey.pub"))
#   key_name   = "mykey"
# }

# resource "aws_instance" "bastion" {
#   ami                         = data.aws_ami.ami.id
#   instance_type               = "t2.micro"
#   associate_public_ip_address = true
#   subnet_id                   = aws_subnet.public[0].id
#   key_name                    = aws_key_pair.main.key_name
#   vpc_security_group_ids      = [aws_security_group.bastion.id]
# }

# resource "aws_security_group" "bastion" {
#   name   = "bastion-sg"
#   vpc_id = aws_vpc.main.id
# }

# resource "aws_vpc_security_group_ingress_rule" "bastion" {
#   ip_protocol       = "tcp"
#   from_port         = 22
#   to_port           = 22
#   security_group_id = aws_security_group.bastion.id
#   cidr_ipv4         = "0.0.0.0/0"
# }

# resource "aws_vpc_security_group_egress_rule" "bastion" {
#   ip_protocol                  = "-1"
#   security_group_id            = aws_security_group.bastion.id
#   referenced_security_group_id = aws_security_group.private.id
# }

# output "bastion" {
#   value = aws_instance.bastion.public_dns
# }
