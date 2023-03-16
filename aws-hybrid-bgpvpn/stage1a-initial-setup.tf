resource "aws_cloudformation_stack" "ADVANCEDVPNDEMO" {
    name = "ADVANCEDVPNDEMO"
    template_url = "https://learn-cantrill-labs.s3.amazonaws.com/aws-hybrid-bgpvpn/BGPVPNINFRA.yaml"
    capabilities = ["CAPABILITY_NAMED_IAM"]
    
}