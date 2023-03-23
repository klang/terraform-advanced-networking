# https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-isolated.html
# with a cross account twist, using RAM

# Three VPCs.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# divided into vpc_in_{dev,test,prod,shared}.tf

# A transit gateway.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection#ec2-transit-gateway
# .. takes a minute to create
resource "aws_ec2_transit_gateway" "example" {
  provider = aws.shared
  description = "No traffic between attached network"
  tags = {
    Name = "Isolated"
  }
  # changing these defaults have not disernable effect
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
#  auto_accept_shared_attachments = "enable"
}

# https://github.com/cloudposse/terraform-aws-transit-gateway/blob/master/ram.tf
resource "aws_ram_resource_share" "vpn" {
  provider = aws.shared
  name = "Shared VPN"
  allow_external_principals = true
  tags = {
    Environment = "Shared Services"
  }
}

resource "aws_ram_resource_association" "tgw" {
  provider = aws.shared
  resource_arn       = aws_ec2_transit_gateway.example.arn
  resource_share_arn = aws_ram_resource_share.vpn.arn
}

resource "aws_ec2_transit_gateway_route_table" "knows_everything" {
  provider = aws.shared
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "Routes to everywhere"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "shared" {
  provider = aws.shared
  subnet_ids         = aws_subnet.subnets_in_shared[*].id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  vpc_id             = aws_vpc.shared.id
  tags = {
    Name = "to shared"
  }
  depends_on = [
    aws_ec2_transit_gateway.example,
  ]
}

resource "aws_ec2_transit_gateway_route_table" "isolation" {
  provider = aws.shared
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  tags = {
    Name = "Route to shared for isolated networks"
  }
}

# associations and propagations are placed in the `vpc_in_{dev,test,prod,shared}.tf` files.
# there are some dependencies between 