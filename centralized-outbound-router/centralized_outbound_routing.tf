data "aws_availability_zones" "available" {}
/* output "availability_zones" {
  value = data.aws_availability_zones.available
} */
output "availability_zone" {
  value = data.aws_availability_zones.available.names[0]
}
# https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-isolated.html

# Three VPCs with IP address ranges that do not overlap. 
# VPC A and VPC B each have private subnets with EC2 instances. (well .. no ec2 instances, right now)
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

#VPC C has the following:

#    An internet gateway attached to the VPC. For more information, see Create and attach an internet gateway in the Amazon VPC User Guide.
#    A public subnet with a NAT gateway. For more information, see Create a NAT gateway in the Amazon VPC User Guide.
#    A private subnet for the transit gateway attachment. The private subnet should be in the same Availability Zone as the public subnet.

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

resource "aws_subnet" "public_subnets_in_vpc_c" {
  count = 2
  vpc_id     = aws_vpc.vpc_c.id
  cidr_block = cidrsubnet(aws_vpc.vpc_c.cidr_block, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC C - public"
  }
} 

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc_c.id
  tags = {
    Name = "main"
  }
}

resource "aws_eip" "nat" {
  count = 2
  depends_on = [
    aws_internet_gateway.gw
  ]
  tags = {
    Name = "eip for NatGateway in public subnet in VPC C - AZ ${count.index + 1}"
  }
}

resource "aws_nat_gateway" "example" {
  count = 2
  allocation_id = aws_eip.nat[count.index].id
  connectivity_type = "public"
  subnet_id     = aws_subnet.public_subnets_in_vpc_c[count.index].id
  tags = {
    Name = "Availability Zone ${count.index + 1} - NatGateway"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}


# A transit gateway.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection#ec2-transit-gateway
# .. takes a minute to create
resource "aws_ec2_transit_gateway" "example" {
  description = "Full mesh"
  tags = {
    Name = "Centralized with outbound"
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

# this will add a static route to the default transit gateway route table
resource "aws_ec2_transit_gateway_route" "static_for_c" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.example.association_default_route_table_id
  depends_on = [
    aws_ec2_transit_gateway.example
  ]
}

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

# The following is an example route table for the public subnet. The first entry enables instances in the VPC to communicate with each other. The second and third entries route traffic for VPC A and VPC B to the transit gateway. The remaining entry routes all other IPv4 subnet traffic to the internet gateway.
resource "aws_route_table" "vpc_c" {
  vpc_id = aws_vpc.vpc_c.id
  # route: "10.3.0.0/16 --> local" is created implicitly
  route {
    cidr_block = aws_vpc.vpc_a.cidr_block
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }
  route {
    cidr_block = aws_vpc.vpc_b.cidr_block
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "from VPC C to Transit Gateway or"
  }
  depends_on = [
    aws_ec2_transit_gateway.example, aws_internet_gateway.gw
  ]
}
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = aws_subnet.public_subnets_in_vpc_c[count.index].id
  route_table_id = aws_route_table.vpc_c.id
}

# The following is an example route table for the private subnet. The first entry enables instances in the VPC to communicate with each other. The second entry routes all other IPv4 subnet traffic to the NAT gateway.
resource "aws_route_table" "private_vpc_c" {
  count = 2
  vpc_id = aws_vpc.vpc_c.id
  # route: "10.3.0.0/16 --> local" is created implicitly
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.example[count.index].id
  }
  tags = {
    Name = "from private subnets in VPC C to Nat Gateway"
  }
  depends_on = [
    aws_internet_gateway.gw, aws_nat_gateway.example
  ]
}
resource "aws_route_table_association" "private" {
  count = 2
  subnet_id      = aws_subnet.subnets_in_vpc_c[count.index].id
  route_table_id = aws_route_table.private_vpc_c[count.index].id
}