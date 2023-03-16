data "aws_availability_zones" "available" {}
/* output "availability_zones" {
  value = data.aws_availability_zones.available
} */
output "availability_zone" {
  value = data.aws_availability_zones.available.names[0]
}
# https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-appliance-scenario.html

# Three VPCs.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "vpc_a" {
  cidr_block = "10.0.0.0/16"
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
    Name = "Availability Zone ${count.index + 1}"
  }
}

resource "aws_vpc" "vpc_b" {
  cidr_block = "10.1.0.0/16"
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
    Name = "Availability Zone ${count.index + 1}"
  }
} 

resource "aws_vpc" "vpc_c" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "VPC C (shared services)"
  }
}

# this is just a trick to make the names match the example and make things a bit easier to read
variable tgw_subnet_names {
  type = list
  default = ["A", "C"]
}

resource "aws_subnet" "subnets_in_vpc_c_tgw_subnets" { # subnets_in_vpc_c_tgw_subnets
  count = 2
  vpc_id     = aws_vpc.vpc_c.id
  cidr_block = cidrsubnet(aws_vpc.vpc_c.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} Subnet ${var.tgw_subnet_names[count.index]} (transit gateway)" # Subnet A and C
  }
}

variable appliance_subnet_names {
  type = list
  default = ["B", "D"]
}

resource "aws_subnet" "subnets_in_vpc_c_appliance_subnets" {
  count = 2
  vpc_id     = aws_vpc.vpc_c.id
  cidr_block = cidrsubnet(aws_vpc.vpc_c.cidr_block, 8, count.index + 2) # cidrs should not clash with the Subnet A cidrs
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} Subnet ${var.appliance_subnet_names[count.index]} (appliance)" # Subnet B and D
  }
}

# A transit gateway.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection#ec2-transit-gateway
# .. takes a minute to create
resource "aws_ec2_transit_gateway" "example" {
  description = "All traffic is routed through the appliance for inspection"
  tags = {
    Name = "Appliance"
  }
  # changing these defaults have not disernable effect
  #default_route_table_association = "disable"
  #default_route_table_propagation = "disable"
}


# Three VPC attachments - one for each of the VPCs.
# For each VPC attachment, specify a subnet in each Availability Zone. Observe, [*] specifies a subnet in each AZ
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment
# .. takes a minute to create attachments to a and b in parallel
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  subnet_ids         = aws_subnet.subnets_in_vpc_a[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.vpc_a.id
  tags = {
    Name = "to VPC A"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  subnet_ids         = aws_subnet.subnets_in_vpc_b[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.vpc_b.id
  tags = {
    Name = "to VPC B"
  }
}


#
# -- TODO -- For the shared services VPC, these are the subnets where traffic is routed to the VPC from the transit gateway. 
# -- TODO -- In the preceding example, these are subnets A and C.
# For the VPC attachment for VPC C, enable appliance mode support
# so that response traffic is routed to the same Availability Zone in VPC C as the source traffic.
# https://github.com/hashicorp/terraform-provider-aws/tree/main/examples/transit-gateway-cross-account-vpc-attachment
# specifically specify the first subnet (subnet A) to connect to the transit gateway
# the appliance will be located in the other subnet (subnet B)
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c" {
  subnet_ids         = aws_subnet.subnets_in_vpc_c_tgw_subnets[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.vpc_c.id
  appliance_mode_support = "enable"
  tags = {
    Name = "to VPC C (shared service) + appliance mode"
  }
}

# https://aws.amazon.com/blogs/networking-and-content-delivery/centralized-inspection-architecture-with-aws-gateway-load-balancer-and-aws-transit-gateway/

output "appliance_mode" {
  value = aws_ec2_transit_gateway_vpc_attachment.vpc_c.appliance_mode_support
}

output "route_table" {
  value = aws_vpc.vpc_a.default_route_table_id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
# Note that the default route, mapping the VPC's CIDR block to "local", is created implicitly and cannot be specified.
# VPCs A and B have route tables with 2 entries. The first entry is the default entry for local IPv4 routing in the VPC. 
# This default entry enables the resources in this VPC to communicate with each other. 
# The second entry routes all other IPv4 subnet traffic to the transit gateway. 
resource "aws_route_table" "vpc_a" {
  vpc_id = aws_vpc.vpc_a.id
  # route: "10.0.0.0/16 --> local" is created implicitly
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
}

resource "aws_route_table" "vpc_b" {
  vpc_id = aws_vpc.vpc_b.id
  # route: "10.1.0.0/16 --> local" is created implicitly
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
}

# VPC C
# The shared services VPC (VPC C) has different route tables for each subnet. 
# Subnet A is used by the transit gateway (you specify this subnet when you create the VPC attachment).
# The route table for subnet A routes all traffic to the appliance in subnet B.

resource "aws_route_table" "vpc_c_transit_gateway" {
  count = 2
  vpc_id = aws_vpc.vpc_c.id
  # route: "192.168.0.0/16 --> local" is created implicitly
  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = aws_network_interface.appliance[count.index].id
  }
  tags = {
    Name = "from Transit Gateway to appliance"
  }
}
resource "aws_route_table_association" "transit_gateway" {
  count = 2
  subnet_id      = aws_subnet.subnets_in_vpc_c_tgw_subnets[count.index].id
  route_table_id = aws_route_table.vpc_c_transit_gateway[count.index].id
} 

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface
resource "aws_network_interface" "appliance" {
  count = 2
  subnet_id       = aws_subnet.subnets_in_vpc_c_appliance_subnets[count.index].id
  private_ips     = [cidrhost(aws_subnet.subnets_in_vpc_c_appliance_subnets[count.index].cidr_block, 50)] # just select the 50th host like in the example from the documentation
  #security_groups = [aws_security_group.web.id]
  tags = {
    Name = "simulated appliance in Availability Zone ${count.index + 1} Subnet ${var.appliance_subnet_names[count.index]}"
  }
}

resource "aws_route_table" "vpc_c_appliance" {
  vpc_id = aws_vpc.vpc_c.id
  # route: "192.168.0.0/16 --> local" is created implicitly
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

# The route table for subnet B (which contains the appliance) routes the traffic back to the transit gateway.
resource "aws_route_table_association" "appliance" {
  count = 2
  subnet_id      = aws_subnet.subnets_in_vpc_c_appliance_subnets[count.index].id
  route_table_id = aws_route_table.vpc_c_appliance.id
}


# Transit gateway route tables
# This transit gateway uses one route table for VPC A and VPC B,
resource "aws_ec2_transit_gateway_route_table" "vpc_a_and_vpc_b" {
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "VPC C attachment associated with route table that routes VPC A and VPC B"
  }
}
#  and one route table for the shared services VPC (VPC C). 
resource "aws_ec2_transit_gateway_route_table" "vpc_c" {
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "VPC A and VPC B attachments associated route table that routes to VPC C"
  }
}

# The VPC A and VPC B attachments are associated with the following route table. The route table routes all traffic to VPC C.
resource "aws_ec2_transit_gateway_route" "to_vpc_c" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc_a_and_vpc_b.id
}

# this will make the propagated routes with the correct route type
resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc_c.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc_c.id
}