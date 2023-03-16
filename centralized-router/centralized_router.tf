data "aws_availability_zones" "available" {}
/* output "availability_zones" {
  value = data.aws_availability_zones.available
} */
output "availability_zone" {
  value = data.aws_availability_zones.available.names[0]
}
# https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-isolated.html

# Three VPCs.
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

resource "aws_vpc" "vpc_c" {
  cidr_block = "10.3.0.0/16"
  tags = {
    Name = "VPC C"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_c" {
  count = 2
  vpc_id     = aws_vpc.vpc_c.id
  cidr_block = cidrsubnet(aws_vpc.vpc_c.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC C"
  }
} 



# A transit gateway.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection#ec2-transit-gateway
# .. takes a minute to create
resource "aws_ec2_transit_gateway" "example" {
  description = "Full mesh"
  tags = {
    Name = "Centralized"
  }
  # changing these defaults have not disernable effect => because it needs time to stabilize
  # enable, if full mesh is what you want, though
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
}

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

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c" {
  subnet_ids         = aws_subnet.subnets_in_vpc_c[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true
  vpc_id             = aws_vpc.vpc_c.id
  tags = {
    Name = "to VPC C"
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
  ]
}

# a VPN Connection
resource "aws_customer_gateway" "example" {
  bgp_asn    = 65000
  ip_address = "172.0.0.1"
  type       = "ipsec.1"
}

resource "aws_vpn_connection" "example" {
  customer_gateway_id = aws_customer_gateway.example.id
  transit_gateway_id  = aws_ec2_transit_gateway.example.id
  type                = aws_customer_gateway.example.type
  depends_on = [
    aws_ec2_transit_gateway.example,
    aws_customer_gateway.example
  ]
}

## Terraform will make the transit gateway attachment for us, just like CDK.
## but, in CDK wee need to make a CustomResorce to get this information and
## the association_default_route_table_id is available directly in terraform.
## this is only available if the transit gateway has a association default table
## in this case we have turned that OFF
## aws_ec2_transit_gateway.example.association_default_route_table_id


# two ways to get the same data out
data "aws_ec2_transit_gateway_vpn_attachment" "vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpn_connection_id  = aws_vpn_connection.example.id
}
output "vpn_attachment" {
  value = data.aws_ec2_transit_gateway_vpn_attachment.vpn.id
}
data "aws_ec2_transit_gateway_attachment" "vpn" {
    filter {
        name = "transit-gateway-id"
        values = [aws_ec2_transit_gateway.example.id]
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
  destination_cidr_block         = "10.99.99.0/24"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.vpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example.association_default_route_table_id
  depends_on = [
    data.aws_ec2_transit_gateway_attachment.vpn
  ]
}
*/

# we need one more thing.
# none of the VPC's can actually route to the TGW

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

resource "aws_route_table" "vpc_c" {
  vpc_id = aws_vpc.vpc_c.id
  # route: "10.3.0.0/16 --> local" is created implicitly
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }
  tags = {
    Name = "from VPC C to Transit Gateway"
  }
  depends_on = [
    aws_ec2_transit_gateway.example
  ]
}

resource "aws_main_route_table_association" "c" {
  vpc_id         = aws_vpc.vpc_c.id
  route_table_id = aws_route_table.vpc_c.id
  depends_on = [
    aws_route_table.vpc_c
  ]
}
