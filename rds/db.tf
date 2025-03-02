provider "aws" {
  region = "eu-central-1"
}

data "aws_iam_policy_document" "this" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.OS.Enabling.html
resource "aws_iam_role" "this" {
  name               = "rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.this.name
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = ["vpc-6b939f00"]
  }
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = data.aws_subnets.default.ids
  name       = "rds-workshop"
}

data "aws_vpc" "this" {
  default = true
}

resource "aws_security_group" "rds" {
  name   = "Allow RDS inbound"
  vpc_id = data.aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.rds.id
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = "0.0.0.0/0"
}

variable "db_password" {
  type = string
}

resource "aws_db_instance" "this" {
  identifier = "rds-pg-labs"

  engine         = "postgres"
  engine_version = "14.12"

  instance_class = "db.t4g.small"
  # iops              = 1000
  allocated_storage = 100

  multi_az                            = false
  iam_database_authentication_enabled = true
  performance_insights_enabled        = true
  # use default KMS key "aws/rds"
  storage_encrypted               = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 1
  monitoring_role_arn             = aws_iam_role.this.arn
  skip_final_snapshot             = true
  publicly_accessible             = true

  username = "postgres"
  password = var.db_password
  port     = 5432
  db_name  = "pglab"

  db_subnet_group_name = aws_db_subnet_group.this.name
  # MUST associate SG, having SG on VPC does not suffice, otherwise psql hangs
  vpc_security_group_ids = [aws_security_group.rds.id]
}



