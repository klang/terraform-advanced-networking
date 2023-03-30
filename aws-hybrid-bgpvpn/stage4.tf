resource "local_file" "bgp-config-router1" {
    content = templatefile(
                "${path.module}/templates/bgp-config.tftpl", 
                {
                    tunnel1_bgp_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel1_vgw_inside_address,
                    tunnel2_bgp_address        = aws_vpn_connection.ONPREM-ROUTER1.tunnel2_vgw_inside_address,
                }
            )
    filename = "connection1bgpconfig.txt"
}


resource "local_file" "bgp-config-router2" {
    content = templatefile(
                "${path.module}/templates/bgp-config.tftpl", 
                {
                    tunnel1_bgp_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel1_vgw_inside_address,
                    tunnel2_bgp_address        = aws_vpn_connection.ONPREM-ROUTER2.tunnel2_vgw_inside_address,
                }
            )
    filename = "connection2bgpconfig.txt"
}
