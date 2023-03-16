data "aws_availability_zones" "available" {}
/* output "availability_zones" {
  value = data.aws_availability_zones.available
} */
output "availability_zone" {
  value = data.aws_availability_zones.available.names[0]
}
# https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-isolated.html

# Two VPCs.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "vpc_a" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "VPC A"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_a" {
  count = 2
  vpc_id     = aws_vpc.vpc_a.id
  cidr_block = cidrsubnet(aws_vpc.vpc_a.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC A"
  }
}

resource "aws_vpc" "vpc_b" {
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "VPC B"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_b" {
  count = 2
  vpc_id     = aws_vpc.vpc_b.id
  cidr_block = cidrsubnet(aws_vpc.vpc_b.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC B"
  }
} 

# Two transit gateways.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection#ec2-transit-gateway
# .. takes a minute to create
resource "aws_ec2_transit_gateway" "example" {
  description = "peered transit gateways (left side)"
  tags = {
    Name = "Transit Gateway 1"
  }
  # changing these defaults have not disernable effect => because it needs time to stabilize
  # enable, if full mesh is what you want, though
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments = "enable"
}

# Two VPC attachments on the first transit gateway. 
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  subnet_ids         = aws_subnet.subnets_in_vpc_a[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true
  vpc_id             = aws_vpc.vpc_a.id
  tags = {
    Name = "to VPC A"
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
  ]
}
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  subnet_ids         = aws_subnet.subnets_in_vpc_b[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true
  vpc_id             = aws_vpc.vpc_b.id
  tags = {
    Name = "to VPC B"
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
  ]
}

# the second Transit Gateway
resource "aws_ec2_transit_gateway" "example_2" {
  description = "peered transit gateways (right side)"
  tags = {
    Name = "Transit Gateway 2"
  }
  # changing these defaults have not disernable effect => because it needs time to stabilize
  # enable, if full mesh is what you want, though
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments = "enable"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_peering_attachment
# we create the transit gateways in different regions and then peer them, but we haven't don that in this example
data "aws_region" "current" {}

resource "aws_ec2_transit_gateway_peering_attachment" "example" {
  peer_account_id         = aws_ec2_transit_gateway.example.owner_id
  peer_region             = data.aws_region.current.name
  peer_transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_id      = aws_ec2_transit_gateway.example_2.id

  tags = {
    Name = "TGW Peering Requestor"
  }
}
# the above will make a transit gateway attachment resource with type "peering" on the accepting TGW
# we have to look it up before we can accept the connection
data "aws_ec2_transit_gateway_attachment" "example" {
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.example.id]
  }

  filter {
    name   = "resource-type"
    values = ["peering"]
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "example" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_attachment.example.id
  tags = {
    Name = "TGW Peering Acceptor"
  }
}

# A Site-to-Site VPN attachment on the transit gateway.
resource "aws_customer_gateway" "example" {
  bgp_asn    = 65000
  ip_address = "172.0.0.1"
  type       = "ipsec.1"
}

resource "aws_vpn_connection" "example" {
  customer_gateway_id = aws_customer_gateway.example.id
  transit_gateway_id  = aws_ec2_transit_gateway.example_2.id
  type                = aws_customer_gateway.example.type
  depends_on = [
    aws_ec2_transit_gateway.example_2,
    aws_customer_gateway.example
  ]
}

data "aws_ec2_transit_gateway_vpn_attachment" "vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.example_2.id
  vpn_connection_id  = aws_vpn_connection.example.id
}
output "vpn_attachment" {
  value = data.aws_ec2_transit_gateway_vpn_attachment.vpn.id
}
data "aws_ec2_transit_gateway_attachment" "vpn" {
    filter {
        name = "transit-gateway-id"
        values = [aws_ec2_transit_gateway.example_2.id]
    }
    filter {
        name = "resource-type"
        values = ["vpn"]
    }
    depends_on = [
      aws_vpn_connection.example,
      aws_customer_gateway.example
    ]
}
output "vpn_attachment_from_filter" {
  value = data.aws_ec2_transit_gateway_attachment.vpn.id
}
# this will add a static route to the default transit gateway route table
# if we had a vpn connection, this route would be propagated by the VPN
/*
resource "aws_ec2_transit_gateway_route" "vpn" {
  destination_cidr_block         = "172.31.0.0/24"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.vpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example_2.association_default_route_table_id
  depends_on = [
    data.aws_ec2_transit_gateway_attachment.vpn
  ]
}
*/

# The following is an example of the default route table for transit gateway 2, with route propagation enabled.
output "peering" {
  value = aws_ec2_transit_gateway_peering_attachment.example.id
}

resource "aws_ec2_transit_gateway_route" "peering_from_tgw_1" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.example.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example.association_default_route_table_id
  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.example,
    aws_ec2_transit_gateway_peering_attachment_accepter.example
  ]
}

resource "aws_ec2_transit_gateway_route" "from_vpc_a_to_peering" {
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.example.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example_2.association_default_route_table_id
  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.example
  ]
}
resource "aws_ec2_transit_gateway_route" "from_vpc_b_to_peering" {
  destination_cidr_block         = "10.2.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.example.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example_2.association_default_route_table_id
  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.example
  ]
}



# we need one more thing.
# none of the VPC's can actually route to the TGW
# Each VPC has a route table with 2 entries. The first entry is the default entry for local IPv4 routing in the VPC. This default entry enables the resources in this VPC to communicate with each other. The second entry routes all other IPv4 subnet traffic to the transit gateway. The following table shows the VPC A routes.
resource "aws_route_table" "vpc_a" {
  vpc_id = aws_vpc.vpc_a.id
  # route: "10.1.0.0/16 --> local" is created implicitly
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }
  tags = {
    Name = "from VPC A to Transit Gateway"
  }
  depends_on = [
    aws_ec2_transit_gateway.example
  ]
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.vpc_a.id
  route_table_id = aws_route_table.vpc_a.id
  depends_on = [
    aws_route_table.vpc_a
  ]
}

resource "aws_route_table" "vpc_b" {
  vpc_id = aws_vpc.vpc_b.id
  # route: "10.2.0.0/16 --> local" is created implicitly
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }
  tags = {
    Name = "from VPC B to Transit Gateway"
  }
  depends_on = [
    aws_ec2_transit_gateway.example
  ]
}

resource "aws_main_route_table_association" "b" {
  vpc_id         = aws_vpc.vpc_b.id
  route_table_id = aws_route_table.vpc_b.id
  depends_on = [
    aws_route_table.vpc_b
  ]
}