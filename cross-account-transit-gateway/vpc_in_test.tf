# this could probably be a module
data "aws_availability_zones" "test" {
  provider = aws.test
}
data "aws_caller_identity" "test" {
  provider = aws.test
}

resource "aws_vpc" "vpc_b" {
  provider = aws.test
  cidr_block = "10.2.0.0/16"
  tags = {
    Name = "VPC B"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_b" {
  provider = aws.test
  count = 2
  vpc_id     = aws_vpc.vpc_b.id
  cidr_block = cidrsubnet(aws_vpc.vpc_b.cidr_block, 8, count.index)
  #availability_zone = data.aws_availability_zones.available.names[count.index]
  availability_zone_id = data.aws_availability_zones.test.zone_ids[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC B"
  }
}

#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------

output "testing_test" {
    value = aws_ec2_transit_gateway_vpc_attachment.vpc_b
    depends_on = [
        aws_ec2_transit_gateway_vpc_attachment.vpc_b,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_b,
        aws_subnet.subnets_in_vpc_b
    ]
}

data "aws_ec2_transit_gateway" "shared_with_test" {
  provider = aws.test
  #id = aws_ec2_transit_gateway.example.id

  filter {
    name   = "options.amazon-side-asn"
    values = ["64512"]
  }
  filter {
    name   = "owner-id"
    values = [data.aws_caller_identity.shared.account_id]
  }
  depends_on = [
        aws_ec2_transit_gateway_vpc_attachment.vpc_b,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_b,
        aws_subnet.subnets_in_vpc_b
    ]
}

output "transit_gateway_shared_with_test" {
    value = data.aws_ec2_transit_gateway.shared_with_test.id
}

resource "aws_route_table" "vpc_b" {
    provider = aws.test
    vpc_id = aws_vpc.vpc_b.id
    # route: "10.2.0.0/16 --> local" is created implicitly
    route {
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = data.aws_ec2_transit_gateway.shared_with_test.id
    }
    tags = {
        Name = "from VPC B to Transit Gateway"
    }
    depends_on = [
        aws_ec2_transit_gateway.example,
        data.aws_ec2_transit_gateway.shared_with_test,
        aws_ec2_transit_gateway_vpc_attachment.vpc_b,
        aws_vpc.vpc_b,
        aws_subnet.subnets_in_vpc_b
    ]
}

resource "aws_main_route_table_association" "b" {
    provider = aws.test
    vpc_id         = aws_vpc.vpc_b.id
    route_table_id = aws_route_table.vpc_b.id
    depends_on = [
        aws_route_table.vpc_b
    ]
}

##
##
##
## transit_gateway_attachment
##
##
##

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share_accepter
resource "aws_ram_principal_association" "test_transit_gateway_invite" {
  provider = aws.shared

  principal          = data.aws_caller_identity.test.account_id
  resource_share_arn = aws_ram_resource_share.vpn.arn
  depends_on = [
    aws_ram_resource_share.vpn
  ]
}

# https://github.com/hashicorp/terraform-provider-aws/issues/8383
# https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/pull/91
#
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b" {
  provider = aws.test
  subnet_ids         = aws_subnet.subnets_in_vpc_b[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  vpc_id             = aws_vpc.vpc_b.id
  tags = {
    Name = "to VPC B"
  }
  depends_on = [
    aws_ram_principal_association.test_transit_gateway_invite,
    aws_ram_resource_association.tgw,
    aws_ec2_transit_gateway.example,
#    data.aws_ec2_transit_gateway.shared_with_test,
    aws_vpc.vpc_b,
    aws_subnet.subnets_in_vpc_b
  ]
  lifecycle {
    ignore_changes = [
      transit_gateway_default_route_table_association,
      transit_gateway_default_route_table_propagation
    ]
  }
}

# should be renamed shared_from_dev
data "aws_ec2_transit_gateway_attachment" "shared_from_test" {
  provider = aws.shared
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.example.id]
  }

  filter {
    name   = "resource-owner-id"
    values = [data.aws_caller_identity.test.account_id]
  }
  
  filter {
    name = "state"
    values = ["pendingAcceptance", "available"]
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
    aws_ec2_transit_gateway_vpc_attachment.vpc_b
  ]
}

output "waiting_for_accept_from_test" {
  value = data.aws_ec2_transit_gateway_attachment.shared_from_test
}

# should be renamed accepted_from_dev
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepted_from_test" {
  provider = aws.shared
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_attachment.shared_from_test.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "cross-account from ${data.aws_caller_identity.test.account_id}"
  }
  depends_on = [
    data.aws_ec2_transit_gateway_attachment.shared_from_test
  ]
}


resource "aws_ec2_transit_gateway_route_table_propagation" "from_test_to_isolation" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared_from_test.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    # it doesn't make sense that the probagation has to wait until the association is done, but here we are
    aws_ec2_transit_gateway_route_table_association.from_shared,
    aws_ec2_transit_gateway_route_table_association.share_from_dev
  ]
}

resource "aws_ec2_transit_gateway_route_table_association" "share_from_test" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared_from_test.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    aws_ec2_transit_gateway_route_table_association.from_shared,
    aws_ec2_transit_gateway_route_table_association.share_from_dev
  ]
}
