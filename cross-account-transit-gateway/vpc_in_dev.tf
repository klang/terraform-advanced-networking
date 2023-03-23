# this could probably be a module
data "aws_availability_zones" "dev" {
  provider = aws.dev
}
data "aws_caller_identity" "dev" {
  provider = aws.dev
}

resource "aws_vpc" "vpc_a" {
  provider = aws.dev
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "VPC A"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_a" {
  provider = aws.dev
  count = 2
  vpc_id     = aws_vpc.vpc_a.id
  cidr_block = cidrsubnet(aws_vpc.vpc_a.cidr_block, 8, count.index)
  #availability_zone = data.aws_availability_zones.available.names[count.index]
  availability_zone_id = data.aws_availability_zones.dev.zone_ids[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC A"
  }
}

#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------

output "testing_dev" {
    value = aws_ec2_transit_gateway_vpc_attachment.vpc_a
    depends_on = [
        aws_ec2_transit_gateway_vpc_attachment.vpc_a,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_a,
        aws_subnet.subnets_in_vpc_a
    ]
}

data "aws_ec2_transit_gateway" "shared_with_dev" {
  provider = aws.dev
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
        aws_ec2_transit_gateway_vpc_attachment.vpc_a,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_a,
        aws_subnet.subnets_in_vpc_a
    ]
}
output "transit_gateway_shared_with_dev" {
    value = data.aws_ec2_transit_gateway.shared_with_dev.id
}


resource "aws_route_table" "vpc_a" {
    provider = aws.dev
    vpc_id = aws_vpc.vpc_a.id
    # route: "10.1.0.0/16 --> local" is created implicitly
    route {
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = data.aws_ec2_transit_gateway.shared_with_dev.id
    }
    tags = {
        Name = "from VPC A to Transit Gateway"
    }
    depends_on = [
        aws_ec2_transit_gateway.example,
        data.aws_ec2_transit_gateway.shared_with_dev,
        aws_ec2_transit_gateway_vpc_attachment.vpc_a,
        aws_vpc.vpc_a,
        aws_subnet.subnets_in_vpc_a
    ]
}

resource "aws_main_route_table_association" "a" {
    provider = aws.dev
    vpc_id         = aws_vpc.vpc_a.id
    route_table_id = aws_route_table.vpc_a.id
    depends_on = [
        aws_route_table.vpc_a
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
resource "aws_ram_principal_association" "dev_transit_gateway_invite" {
  provider = aws.shared

  principal          = data.aws_caller_identity.dev.account_id
  resource_share_arn = aws_ram_resource_share.vpn.arn
  depends_on = [
    aws_ram_resource_share.vpn
  ]
}

# https://github.com/hashicorp/terraform-provider-aws/issues/8383
# https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/pull/91
# should be renamed from_dev
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  provider = aws.dev
  subnet_ids         = aws_subnet.subnets_in_vpc_a[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  vpc_id             = aws_vpc.vpc_a.id
  tags = {
    Name = "to VPC A"
  }
  depends_on = [
    aws_ram_principal_association.dev_transit_gateway_invite,
    aws_ram_resource_association.tgw,
    aws_ec2_transit_gateway.example,
#    data.aws_ec2_transit_gateway.shared_with_dev,
    aws_vpc.vpc_a,
    aws_subnet.subnets_in_vpc_a
  ]
  lifecycle {
    ignore_changes = [
      transit_gateway_default_route_table_association,
      transit_gateway_default_route_table_propagation
    ]
  }
}

# should be renamed shared_from_dev
data "aws_ec2_transit_gateway_attachment" "shared" {
  provider = aws.shared
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.example.id]
  }

  filter {
    name   = "resource-owner-id"
    values = [data.aws_caller_identity.dev.account_id]
  }
  
  filter {
    name = "state"
    values = ["pendingAcceptance", "available"]
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
    aws_ec2_transit_gateway_vpc_attachment.vpc_a
  ]
}

output "waiting_for_accept" {
  value = data.aws_ec2_transit_gateway_attachment.shared
}

# should be renamed accepted_from_dev
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "example" {
  provider = aws.shared
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_attachment.shared.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "cross-account from ${data.aws_caller_identity.dev.account_id}"
  }
  depends_on = [
    data.aws_ec2_transit_gateway_attachment.shared
  ]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "from_dev_to_isolation" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    aws_ec2_transit_gateway_route_table_association.from_shared
  ]
}

resource "aws_ec2_transit_gateway_route_table_association" "share_from_dev" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    aws_ec2_transit_gateway_route_table_association.from_shared
  ]
}
