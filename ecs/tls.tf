# for development only
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]

  is_ca_certificate     = true
  private_key_pem       = tls_private_key.ca.private_key_pem
  validity_period_hours = 120

  subject {
    common_name         = "bobstrong.eu"
    country             = "ES"
    organization        = "AWS Workshop"
    organizational_unit = "ECS"
  }
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
}

# CSR
resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  # SAN (subject alternative name), match other domains apart from common name
  dns_names = ["dev.ecs.bobstrong.eu", "acct.ecs.bobstrong.eu"]

  subject {
    common_name         = "ecs.bobstrong.eu"
    country             = "ES"
    organization        = "AWS Workshop"
    organizational_unit = "ECS"
  }
}

# tls cert signed by CA
# authority key identifier matches identifier in CA cert (signer)
resource "tls_locally_signed_cert" "server" {
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]

  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  validity_period_hours = 120
}

# imported cert is not rotated by aws
# todo create cert using ACM
resource "aws_acm_certificate" "server" {
  private_key      = tls_private_key.server.private_key_pem
  certificate_body = tls_locally_signed_cert.server.cert_pem
}

# ALB will always terminate TLS connection (or re-encrypt after), NLB can also passthrough
resource "aws_lb_listener" "tls" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.server.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
