resource "aws_db_subnet_group" "this" {
  subnet_ids = module.vpc.private_subnets
  name       = "retail-store"
}

resource "aws_security_group" "db" {
  name   = "retail-store-db"
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "db" {
  ip_protocol       = "-1"
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.db.id
  from_port                    = aws_db_instance.catalog.port
  to_port                      = aws_db_instance.catalog.port
  referenced_security_group_id = aws_security_group.service.id
}

resource "aws_db_instance" "catalog" {
  identifier        = "retail-store-db"
  db_name           = "catalog"
  allocated_storage = 5

  engine = "mysql"
  # weird authenication error in catalog service, manual connection works, DB version related? 
  engine_version = "8.4"
  instance_class = "db.t3.micro"

  manage_master_user_password = true
  # creates entry in myslql.user table, e.g. user = catalog, host = %
  username = "catalog"

  #parameter_group_name = "default.mysql8.0"
  skip_final_snapshot    = true
  apply_immediately      = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
}

resource "aws_ssm_parameter" "endpoint" {
  name  = "/retail-store/catalog/db-endpoint"
  type  = "String"
  value = aws_db_instance.catalog.endpoint
}

# install mariadb server package to get mysql cli
# module "bastion" {
#   source    = "../modules/private-bastion"
#   subnet_id = module.vpc.private_subnets[0]
# }

# resource "aws_vpc_security_group_ingress_rule" "bastion" {
#   ip_protocol                  = "tcp"
#   security_group_id            = aws_security_group.db.id
#   from_port                    = aws_db_instance.catalog.port
#   to_port                      = aws_db_instance.catalog.port
#   referenced_security_group_id = module.bastion.sg_id
# }

# output "bastion" {
#   value = module.bastion
# }
