provider "aws" {
  region = "eu-central-1"
}

# for development only
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "key" {
  filename        = "${path.module}/ca.pem"
  content         = tls_private_key.ca.private_key_pem
  file_permission = "0600"
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
    # common_name = "domain"
    country             = "ES"
    organization        = "AWS Workshop"
    organizational_unit = "ECS"
  }
}

resource "local_file" "crt" {
  filename        = "${path.module}/ca.crt"
  content         = tls_self_signed_cert.ca.cert_pem
  file_permission = "0600"
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
}

# CSR
resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  # SAN (subject alternative name), match other domains apart from common name
  dns_names = ["dev.workshop.internal"]

  subject {
    # common_name = "server.domain"
    country             = "ES"
    organization        = "AWS Workshop"
    organizational_unit = "ECS"
  }
}

# tls cert signed by CA
# authority key identifier matches identifier in CA cert (signer)
resource "tls_locally_signed_cert" "name" {
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
