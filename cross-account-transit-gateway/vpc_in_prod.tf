# this could probably be a module
data "aws_availability_zones" "prod" {
  provider = aws.prod
}
data "aws_caller_identity" "prod" {
  provider = aws.prod
}

resource "aws_vpc" "vpc_c" {
  provider = aws.prod
  cidr_block = "10.3.0.0/16"
  tags = {
    Name = "VPC C"
  }
}

# one subnet in each AZ.
resource "aws_subnet" "subnets_in_vpc_c" {
  provider = aws.prod
  count = 2
  vpc_id     = aws_vpc.vpc_c.id
  cidr_block = cidrsubnet(aws_vpc.vpc_c.cidr_block, 8, count.index)
  #availability_zone = data.aws_availability_zones.available.names[count.index]
  availability_zone_id = data.aws_availability_zones.prod.zone_ids[count.index]
  tags = {
    Name = "Availability Zone ${count.index + 1} - VPC C"
  }
}

#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------

output "testing_prod" {
    value = aws_ec2_transit_gateway_vpc_attachment.vpc_c
    depends_on = [
        aws_ec2_transit_gateway_vpc_attachment.vpc_c,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_c,
        aws_subnet.subnets_in_vpc_c
    ]
}

data "aws_ec2_transit_gateway" "shared_with_prod" {
  provider = aws.prod
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
        aws_ec2_transit_gateway_vpc_attachment.vpc_c,
        aws_ec2_transit_gateway.example,
        aws_vpc.vpc_c,
        aws_subnet.subnets_in_vpc_c
    ]
}

output "transit_gateway_shared_with_prod" {
    value = data.aws_ec2_transit_gateway.shared_with_prod.id
}

resource "aws_route_table" "vpc_c" {
    provider = aws.prod
    vpc_id = aws_vpc.vpc_c.id
    # route: "10.3.0.0/16 --> local" is created implicitly
    route {
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = data.aws_ec2_transit_gateway.shared_with_prod.id
    }
    tags = {
        Name = "from VPC C to Transit Gateway"
    }
    depends_on = [
        aws_ec2_transit_gateway.example,
        data.aws_ec2_transit_gateway.shared_with_prod,
        aws_ec2_transit_gateway_vpc_attachment.vpc_c,
        aws_vpc.vpc_c,
        aws_subnet.subnets_in_vpc_c
    ]
}

resource "aws_main_route_table_association" "c" {
    provider = aws.prod
    vpc_id         = aws_vpc.vpc_c.id
    route_table_id = aws_route_table.vpc_c.id
    depends_on = [
        aws_route_table.vpc_c
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
resource "aws_ram_principal_association" "prod_transit_gateway_invite" {
  provider = aws.shared

  principal          = data.aws_caller_identity.prod.account_id
  resource_share_arn = aws_ram_resource_share.vpn.arn
  depends_on = [
    aws_ram_resource_share.vpn
  ]
}

# https://github.com/hashicorp/terraform-provider-aws/issues/8383
# https://github.com/terraform-aws-modules/terraform-aws-transit-gateway/pull/91
#
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c" {
  provider = aws.prod
  subnet_ids         = aws_subnet.subnets_in_vpc_c[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  vpc_id             = aws_vpc.vpc_c.id
  tags = {
    Name = "to VPC C"
  }
  depends_on = [
    aws_ram_principal_association.prod_transit_gateway_invite,
    aws_ram_resource_association.tgw,
    aws_ec2_transit_gateway.example,
#    data.aws_ec2_transit_gateway.shared_with_prod,
    aws_vpc.vpc_c,
    aws_subnet.subnets_in_vpc_c
  ]
  lifecycle {
    ignore_changes = [
      transit_gateway_default_route_table_association,
      transit_gateway_default_route_table_propagation
    ]
  }
}

# should be renamed shared_from_dev
data "aws_ec2_transit_gateway_attachment" "shared_from_prod" {
  provider = aws.shared
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.example.id]
  }

  filter {
    name   = "resource-owner-id"
    values = [data.aws_caller_identity.prod.account_id]
  }
  
  filter {
    name = "state"
    values = ["pendingAcceptance", "available"]
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
    aws_ec2_transit_gateway_vpc_attachment.vpc_c
  ]
}

output "waiting_for_accept_from_prod" {
  value = data.aws_ec2_transit_gateway_attachment.shared_from_prod
}

# should be renamed accepted_from_dev
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepted_from_prod" {
  provider = aws.shared
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_attachment.shared_from_prod.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "cross-account from ${data.aws_caller_identity.prod.account_id}"
  }
  depends_on = [
    data.aws_ec2_transit_gateway_attachment.shared_from_prod
  ]
}


resource "aws_ec2_transit_gateway_route_table_propagation" "from_prod_to_isolation" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared_from_prod.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.knows_everything.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    # it doesn't make sense that the probagation has to wait until the association is done, but here we are
    aws_ec2_transit_gateway_route_table_association.from_shared,
    aws_ec2_transit_gateway_route_table_association.share_from_dev,
    aws_ec2_transit_gateway_route_table_association.share_from_test
  ]
}

resource "aws_ec2_transit_gateway_route_table_association" "share_from_prod" {
  provider = aws.shared
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_attachment.shared_from_prod.id # should be renamed shared_from_dev
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.isolation.id
  depends_on = [
    # wait until previous adjustments are finished (parallel adjustments to a route tabel isn't possible)
    aws_ec2_transit_gateway_route_table_association.from_shared,
    aws_ec2_transit_gateway_route_table_association.share_from_dev,
    aws_ec2_transit_gateway_route_table_association.share_from_test
  ]
}
