data "aws_availability_zones" "shared" {
  provider = aws.shared
}
data "aws_caller_identity" "shared" {
  provider = aws.shared
}

resource "aws_vpc" "shared" {
  provider = aws.shared
  cidr_block = "10.4.0.0/16"
  tags = {
    Name = "Shared"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_shared" {
  provider = aws.shared
  count = 2
  vpc_id     = aws_vpc.shared.id
  cidr_block = cidrsubnet(aws_vpc.shared.cidr_block, 8, count.index)
  #availability_zone = data.aws_availability_zones.shared.names[count.index]
  availability_zone_id = data.aws_availability_zones.shared.zone_ids[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - SHARED"
  }
} 

#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------


resource "aws_route_table" "shared" {
    provider = aws.shared
    vpc_id = aws_vpc.shared.id
    # route: "10.4.0.0/16 --> local" is created implicitly
    route {
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = aws_ec2_transit_gateway.example.id
    }
    tags = {
        Name = "from Shared VPC to Transit Gateway"
    }
    depends_on = [
        aws_ec2_transit_gateway.example,
        aws_ec2_transit_gateway_vpc_attachment.shared
    ]
}

resource "aws_main_route_table_association" "shared" {
    provider = aws.shared
    vpc_id         = aws_vpc.shared.id
    route_table_id = aws_route_table.shared.id
    depends_on = [
        aws_route_table.shared
    ]
}

resource "aws_ec2_transit_gateway_route_table_association" "from_shared" {
  provider = aws.shared
  #transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.shared
  ]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "from_vpc_c_to_isolation" {
  provider = aws.shared
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
}