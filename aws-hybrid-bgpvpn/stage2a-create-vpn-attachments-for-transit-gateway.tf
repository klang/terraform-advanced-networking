data "aws_ec2_transit_gateway" "tgw" {
  filter {
    name   = "options.amazon-side-asn"
    values = ["64512"]
  }
  depends_on = [
    aws_cloudformation_stack.ADVANCEDVPNDEMO
  ]
}
data "aws_customer_gateway" "ONPREM-ROUTER1" {
  filter {
    name   = "ip-address"
    values = [data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"]]
  }
  depends_on = [
    aws_customer_gateway.ONPREM-ROUTER1
  ]
}
data "aws_customer_gateway" "ONPREM-ROUTER2" {
  filter {
    name   = "ip-address"
    values = [data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"]]
  }
  depends_on = [
    aws_customer_gateway.ONPREM-ROUTER2
  ]
}

# Terraform will not let us make a transit gateway vpn attachment.
# .. but it will make that attachment for us when we make the vpn connection itself.

resource "aws_vpn_connection" "ONPREM-ROUTER1" {
  customer_gateway_id = data.aws_customer_gateway.ONPREM-ROUTER1.id
  transit_gateway_id  = data.aws_ec2_transit_gateway.tgw.id
  type                = data.aws_customer_gateway.ONPREM-ROUTER1.type
  enable_acceleration = true
  tags = {
    Name = "ONPREM-ROUTER1"
  }
  depends_on = [
    aws_vpn_connection.ONPREM-ROUTER1
  ]
}

resource "aws_vpn_connection" "ONPREM-ROUTER2" {
  customer_gateway_id = data.aws_customer_gateway.ONPREM-ROUTER2.id
  transit_gateway_id  = data.aws_ec2_transit_gateway.tgw.id
  type                = data.aws_customer_gateway.ONPREM-ROUTER2.type
  enable_acceleration = true
  tags = {
    Name = "ONPREM-ROUTER2"
  }
  depends_on = [
    aws_vpn_connection.ONPREM-ROUTER2
  ]
}

/*
data "aws_ec2_transit_gateway_vpn_attachment" "ONPREM-ROUTER1" {
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw.id
  vpn_connection_id  = aws_vpn_connection.ONPREM-ROUTER1.id
}
output "vpn-attachment-router1" {
    value = data.aws_ec2_transit_gateway_vpn_attachment.ONPREM-ROUTER1.id
}
data "aws_ec2_transit_gateway_vpn_attachment" "ONPREM-ROUTER2" {
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw.id
  vpn_connection_id  = aws_vpn_connection.ONPREM-ROUTER2.id
}
output "vpn-attachment-router2" {
    value = data.aws_ec2_transit_gateway_vpn_attachment.ONPREM-ROUTER2.id
}
*/

# download the generic configuration files manually
resource "local_file" "customer-gateway-config-1" {
    content  = aws_vpn_connection.ONPREM-ROUTER1.customer_gateway_configuration
    filename = "${aws_vpn_connection.ONPREM-ROUTER1.id}-connection1config.xml"
}

resource "local_file" "customer-gateway-config-2" {
    content  = aws_vpn_connection.ONPREM-ROUTER2.customer_gateway_configuration
    filename = "${aws_vpn_connection.ONPREM-ROUTER2.id}-connection2config.xml"
}

resource "local_file" "connection1" {
    content = templatefile(
                "${path.module}/templates/on-prem-router-config.tftpl", 
                {
                    onprem_inside_address      = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Private"],
                    onprem_outside_address     = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"],

                    tunnel1_address            = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_address,
                    tunnel1_preshared_key      = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_preshared_key,
                    #tunnel1_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel1_cgw_inside_address}/30",
                    tunnel1_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel1_cgw_inside_address}/30",
                    tunnel1_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel1_vgw_inside_address}/30",
                    tunnel1_bgp_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_vgw_inside_address,

                    tunnel2_address            = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_address,
                    tunnel2_preshared_key      = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_preshared_key,
                    tunnel2_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel2_cgw_inside_address}/30",
                    tunnel2_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel2_vgw_inside_address}/30",
                    tunnel2_bgp_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_vgw_inside_address,
                }
            )
    filename = "connection1config.txt"
}

resource "local_file" "connection2" {
    content = templatefile(
                "${path.module}/templates/on-prem-router-config.tftpl", 
                {
                    onprem_inside_address      = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Private"],
                    onprem_outside_address     = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"],

                    tunnel1_address            = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_address,
                    tunnel1_preshared_key      = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_preshared_key,
                    tunnel1_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel1_cgw_inside_address}/30",
                    tunnel1_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel1_vgw_inside_address}/30",
                    tunnel1_bgp_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_vgw_inside_address,

                    tunnel2_address            = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_address,
                    tunnel2_preshared_key      = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_preshared_key,
                    tunnel2_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel2_cgw_inside_address}/30",
                    tunnel2_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel2_vgw_inside_address}/30",
                    tunnel2_bgp_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_vgw_inside_address,
                }
            )
    filename = "connection2config.txt"
}
