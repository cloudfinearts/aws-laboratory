resource "aws_ec2_transit_gateway" "main" {
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}

# TGW ENI placed in a dedicated subnet
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc_a.id
  subnet_ids         = [aws_subnet.tgw_a.id]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "tgw-attachment-vpc-a"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc_b.id
  subnet_ids         = [aws_subnet.tgw_b.id]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "tgw-attachment-vpc-b"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc_c.id
  subnet_ids         = [aws_subnet.tgw_c.id]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "tgw-attachment-vpc-c"
  }
}

# Shared route table — used by VPC A (the hub).
# VPC B and C propagate their CIDRs here so VPC A can reach both.
resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "tgw-rt-shared"
  }
}

# Spoke route table — used by VPC B and VPC C.
# Only VPC A propagates here, so B and C can reach A but not each other.
resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "tgw-rt-spoke"
  }
}

# --- Associations ---
# VPC A looks up routes in the shared table
resource "aws_ec2_transit_gateway_route_table_association" "vpc_a" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
}

# VPC B and C look up routes in the spoke table
resource "aws_ec2_transit_gateway_route_table_association" "vpc_b" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc_c" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
}

# --- Propagations into shared table (VPC A's view) ---
# B and C advertise their CIDRs so VPC A can route to them
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_b_to_shared" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_c_to_shared" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
}

# --- Propagations into spoke table (VPC B and C's view) ---
# Only VPC A advertises its CIDR — B and C have no route to each other
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_a_to_spoke" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
}
