resource "aws_secretsmanager_secret" "this" {
  name = "masterPostgresCredentials"
}

locals {
  secret = {
    username = "postgres"
    password = var.db_password
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(local.secret)
}

data "aws_iam_policy_document" "proxy-trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# default KMS used for DB encryption
data "aws_kms_alias" "this" {
  name = "alias/aws/rds"
}

data "aws_iam_policy_document" "proxy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.this.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.this.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      # secret manager from the region can call KMS operation
      values = [format("secretsmanager.%s.amazonaws.com", data.aws_region.this.name)]
    }
  }
}

resource "aws_iam_role" "proxy" {
  assume_role_policy = data.aws_iam_policy_document.proxy-trust.json
  name               = "rds-proxy"
}

resource "aws_iam_role_policy" "proxy" {
  policy = data.aws_iam_policy_document.proxy.json
  role   = aws_iam_role.proxy.id
}

resource "aws_security_group" "proxy" {
  name   = "Allow RDS Proxy"
  vpc_id = data.aws_vpc.this.id
}

// critical, otherwise cannot access target DB, proxy in pending state
resource "aws_vpc_security_group_egress_rule" "proxy" {
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.proxy.id
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_ingress_rule" "proxy" {
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.proxy.id
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = "0.0.0.0/0"
}

# proxy endpoint available only on private address, use NLB for public access
resource "aws_db_proxy" "this" {
  engine_family = "POSTGRESQL"
  name          = "rds-workshop-proxy"
  # get creds from Secrets Manager for connection to the instance
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = data.aws_subnets.default.ids
  vpc_security_group_ids = [aws_security_group.proxy.id]
  auth {
    secret_arn = aws_secretsmanager_secret.this.arn
    # re-sets on every apply if omitted
    auth_scheme               = "SECRETS"
    iam_auth                  = "DISABLED"
    client_password_auth_type = "POSTGRES_SCRAM_SHA_256"
  }
  debug_logging = true
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
  connection_pool_config {
    max_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "this" {
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
  db_instance_identifier = aws_db_instance.this.identifier
}
