data "aws_cloudformation_stack" "ADVANCEDVPNDEMO" {
    name = "ADVANCEDVPNDEMO"
    depends_on = [
      aws_cloudformation_stack.ADVANCEDVPNDEMO
    ]
}

output "Router1Public" {
    value = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"]
}

output "Router2Public" {
    value = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"]
}


resource "aws_customer_gateway" "ONPREM-ROUTER1" {
    device_name = "ONPREM-ROUTER1"
    bgp_asn    = 65016
    ip_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router1Public"]
    type       = "ipsec.1"
}

resource "aws_customer_gateway" "ONPREM-ROUTER2" {
    device_name = "ONPREM-ROUTER2"
    bgp_asn    = 65016
    ip_address = data.aws_cloudformation_stack.ADVANCEDVPNDEMO.outputs["Router2Public"]
    type       = "ipsec.1"
}