klang> Give me a terraform script for creating isolated networks in AWS, using a Transit Gateway

ChatGPT> Sure! Here's an example Terraform script for creating isolated networks in AWS using a Transit Gateway:

[](./suggestion_1.md)

klang> aws_ec2_transit_gateway_vpc_attachment's need to know subnet_ids, can you add that?

ChatGPT> Yes, you're right. In order to create the aws_ec2_transit_gateway_vpc_attachment resource, you need to provide the subnet_ids of the subnets in each VPC that you want to attach to the Transit Gateway. Here's the updated script with those changes:

[](./suggestion_2.md)

Removal of the provider (as it is already defined in my setup) will produce a terraform script that will successfully plan..