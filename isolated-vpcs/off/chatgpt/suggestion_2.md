    # Define provider and region
    provider "aws" {
    region = "us-east-1"
    }

    # Create VPCs
    resource "aws_vpc" "vpc1" {
    cidr_block = "10.0.1.0/24"
    }

    resource "aws_vpc" "vpc2" {
    cidr_block = "10.0.2.0/24"
    }

    # Create subnets
    resource "aws_subnet" "subnet1" {
    vpc_id     = aws_vpc.vpc1.id
    cidr_block = "10.0.1.0/25"
    }

    resource "aws_subnet" "subnet2" {
    vpc_id     = aws_vpc.vpc2.id
    cidr_block = "10.0.2.0/25"
    }

    # Create a Transit Gateway
    resource "aws_ec2_transit_gateway" "transit_gateway" {
    description = "Transit Gateway for isolated networks"
    }

    # Attach VPCs to Transit Gateway
    resource "aws_ec2_transit_gateway_vpc_attachment" "vpc1_attachment" {
    subnet_ids         = [aws_subnet.subnet1.id]
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id             = aws_vpc.vpc1.id
    }

    resource "aws_ec2_transit_gateway_vpc_attachment" "vpc2_attachment" {
    subnet_ids         = [aws_subnet.subnet2.id]
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id             = aws_vpc.vpc2.id
    }

    # Create routes for each VPC
    resource "aws_ec2_transit_gateway_route_table" "vpc1_route_table" {
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }

    resource "aws_ec2_transit_gateway_route_table_association" "vpc1_association" {
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc1_attachment.id
    transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc1_route_table.id
    }

    resource "aws_ec2_transit_gateway_route" "vpc1_route" {
    destination_cidr_block = aws_subnet.subnet2.cidr_block
    transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc1_route_table.id
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc2_attachment.id
    }

    resource "aws_ec2_transit_gateway_route_table" "vpc2_route_table" {
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }

    resource "aws_ec2_transit_gateway_route_table_association" "vpc2_association" {
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc2_attachment.id
    transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc2_route_table.id
    }

    resource "aws_ec2_transit_gateway_route" "vpc2_route" {
    destination_cidr_block = aws_subnet.subnet1.cidr_block
    transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc2_route_table.id
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.vpc1_attachment.id
    }
