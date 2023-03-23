# This is a minimal example to ensure that I understand the concepts.

# this sets up the exact same situation as 
#  - peering A and C
#  - peering B and C
# NOT peering A and B
# i.e A and B are isolated from each other but can both talk to C and C can talk to both A and B

# using vpc peering is all well and good, but it doesn't scale very well.

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
  cidr_block = "10.16.0.0/16"
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
  cidr_block = "10.17.0.0/16"
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
  cidr_block = "10.18.0.0/16"
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
  description = "No traffic between attached network"
  tags = {
    Name = "Isolated"
  }
  # changing these defaults have not disernable effect
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}

# add all the attachments, but don't include any default associations or propagations

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

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c" {
  subnet_ids         = aws_subnet.subnets_in_vpc_c[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.vpc_c.id
  tags = {
    Name = "to VPC C"
  }
}


# free communication between (VPC A and B) and VPC C and vice versa .. but no communication between A and B


# 1 route table .. probagate all attachment to this

resource "aws_ec2_transit_gateway_route_table" "knows_everything" {
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "Routes to everywhere"
  }
}

# everybody probagates their routes to the table that knows everything
resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_c" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
}

# then, we associate this with vpc_c, which will now know everything
resource "aws_ec2_transit_gateway_route_table_association" "vpc_c" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
}
## everything in VPC C will be able to route to everything in VPC A and VPC B, now
  
# another route table

resource "aws_ec2_transit_gateway_route_table" "isolation" {
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "Routes to isolated network"
  }
}
# tell the route table about vpc_c 
resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_c_to_isolation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_c.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
}
# then, we associate this with vpc_a and vpc_c, which will now know the isolated routes to vpc_c (i.e. they can not route to each other)
resource "aws_ec2_transit_gateway_route_table_association" "vpc_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
}
resource "aws_ec2_transit_gateway_route_table_association" "vpc_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
}

# we need one more thing.
# none of the VPC's can actually route to the TGW

resource "aws_route_table" "vpc_a" {
  vpc_id = aws_vpc.vpc_a.id
  # route: "10.16.0.0/16 --> local" is created implicitly
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
  # route: "10.17.0.0/16 --> local" is created implicitly
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
  # route: "10.18.0.0/16 --> local" is created implicitly
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
