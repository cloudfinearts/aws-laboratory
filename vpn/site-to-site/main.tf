
# if default provider does not exist, terraform will create it
provider "aws" {
  region = "eu-central-1"
}

# put on-prem to another region
# modules will not help with multi-region resources since default provider cannot be overriden
# just set custom provider for each resource
provider "aws" {
  region = "us-east-2"
  alias  = "onprem"
}

resource "aws_customer_gateway" "vpn" {
  type        = "ipsec.1"
  ip_address  = aws_instance.onprem.public_ip
  device_name = "Cisco Router XY"

  lifecycle {
    ignore_changes = [bgp_asn]
  }
}

# virtual private gateway aka VGW
resource "aws_vpn_gateway" "vpn" {
  vpc_id = aws_vpc.cloud.id
}

resource "aws_vpn_connection" "vpn" {
  customer_gateway_id = aws_customer_gateway.vpn.id
  vpn_gateway_id      = aws_vpn_gateway.vpn.id
  type                = "ipsec.1"
  # not using BGP for simplicity
  static_routes_only = true

  local_ipv4_network_cidr  = aws_vpc.onprem.cidr_block
  remote_ipv4_network_cidr = aws_vpc.cloud.cidr_block
}

# not required
# resource "aws_vpn_connection_route" "vpn" {
#   destination_cidr_block = aws_vpc.onprem.cidr_block
#   vpn_connection_id      = aws_vpn_connection.vpn.id
# }
