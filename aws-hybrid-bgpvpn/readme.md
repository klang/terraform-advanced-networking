# Advanced Demo - Site-To-Site VPN

[from Adrian Cantrill's course material](https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-hybrid-bgpvpn)

# setup

    awsume training --region us-east-1
    terraform init
    terraform plan
    terraform apply

This will activate the [one click deployment of stack ADVANCEDVPNDEMO](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://learn-cantrill-labs.s3.amazonaws.com/aws-hybrid-bgpvpn/BGPVPNINFRA.yaml&stackName=ADVANCEDVPNDEMO) and apply all the changes needed.

# cleanup

    awsume training --region us-east-1
    terraform destroy

