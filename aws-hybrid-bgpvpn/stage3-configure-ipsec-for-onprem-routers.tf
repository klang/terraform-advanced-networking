resource "local_file" "ipsec-config-1" {
    content = templatefile(
                "${path.module}/templates/ipsec.conf.tftpl", 
                {
                    onprem_inside_address  = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Private"],
                    onprem_outside_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"],
                    tunnel1_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_address,
                    tunnel2_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_address,
                }
            )
    filename = "connection1ipsecconf.txt"
}

resource "local_file" "ipsec-config-2" {
    content = templatefile(
                "${path.module}/templates/ipsec.conf.tftpl", 
                {
                    onprem_inside_address  = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Private"],
                    onprem_outside_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"],
                    tunnel1_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_address,
                    tunnel2_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_address,
                }
            )
    filename = "connection2ipsecconf.txt"
}

resource "local_file" "ipsec-secrets-1" {
    content = templatefile(
                "${path.module}/templates/ipsec.secrets.tftpl", 
                {
                    onprem_outside_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"],
                    tunnel1_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_address,
                    tunnel1_preshared_key  = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_preshared_key,

                    tunnel2_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_address,
                    tunnel2_preshared_key  = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_preshared_key,
                }
            )
    filename = "connection1ipsecsecrets.txt"
}
resource "local_file" "ipsec-secrets-2" {
    content = templatefile(
                "${path.module}/templates/ipsec.secrets.tftpl", 
                {
                    onprem_outside_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"],
                    tunnel1_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_address,
                    tunnel1_preshared_key  = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_preshared_key,

                    tunnel2_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_address,
                    tunnel2_preshared_key  = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_preshared_key,
                }
            )
    filename = "connection2ipsecsecrets.txt"
}


resource "local_file" "ipsec-vti-sh-1" {
    content = templatefile(
                "${path.module}/templates/ipsec-vti.tftpl", 
                {
                    tunnel1_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel1_cgw_inside_address}/30",
                    tunnel1_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel1_vgw_inside_address}/30",

                    tunnel2_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel2_cgw_inside_address}/30",
                    tunnel2_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER1.tunnel2_vgw_inside_address}/30",
                }
            )
    filename = "connection1ipsecvtish.txt"
}

resource "local_file" "ipsec-vti-sh-2" {
    content = templatefile(
                "${path.module}/templates/ipsec-vti.tftpl", 
                {
                    tunnel1_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel1_cgw_inside_address}/30",
                    tunnel1_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel1_vgw_inside_address}/30",

                    tunnel2_cgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel2_cgw_inside_address}/30",
                    tunnel2_vgw_inside_address = "${aws_vpn_connection.ONPREM-ROUTER2.tunnel2_vgw_inside_address}/30",
                }
            )
    filename = "connection2ipsecvtish.txt"
}
