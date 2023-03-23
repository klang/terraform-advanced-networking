# Cross-Account Transit Gateway

This is an extension of the [Isolated VPCs with shared services](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-isolated-shared.html) example from the documentation.

There are some extra moving parts that need to be coordinated, when juggling several accounts and sharing a Transit Gateway via RAM. 

This example shows how to set this up.

It is assumed that the accounts in play are all part of the same AWS Organization.

# terraform 

This project will create the resources needed to create a minimal setup that has isolation between different environments on one side and full access to/from a shared vpc on the other. The one-account version of this is available [here](./off/isolated_routing_minimal.tf). 

![cross-platform-transit-gateway](./AdvancedNetworking-cross-account%20transit%20gateway.drawio.png)

## init

    touch readme.md backend.tf provider.tf variables.tf main.tf
    # add the appropriate resources to the *.tf files
    tfswitch 1.3.9
    terraform init
    awsume iam

## workspaces

It is possible to have a full workspace specific set of accounts if needed. Adjust [variables.tf](./variables.tf) for this.

    terraform workspace new training

## add the AWS config

The usual setting in [~/aws/config](~/aws/config) 

    [default]
    aws_access_key_id = fake
    aws_secret_access_key = fake
    cli_pager=

    [iam]
    #__name__=iam

    [profile training]
    role_arn=arn:aws:iam::<SHAREDSERVICESACCOUNT>:role/cloudpartners-iam
    source_profile=iam

    [profile training-alt]
    role_arn=arn:aws:iam::<DEVACCOUNT>:role/cloudpartners-iam
    source_profile=iam

    [profile training-alt2]
    role_arn=arn:aws:iam::<TESTACCOUNT>:role/cloudpartners-iam
    source_profile=iam

    [profile training-alt3]
    role_arn=arn:aws:iam::<PRODACCOUNT>:role/cloudpartners-iam
    source_profile=iam

The source profile is defined in [~/aws/credentials](~/aws/credentials) as usual:

    [iam]
    aws_access_key_id = 
    aws_secret_access_key = 
    region = eu-west-1
    mfa_serial = arn:aws:iam::<IAMACCOUNT>:mfa/karsten
    __name__ = iam


## add Terraform iam role

The settings in `variables.tf` set up the providers needed in `provider.tf`, but require a `terraform` role on the target accounts.

The template is `cross-account-access-terraform.yaml` and has to be added 

    awsume training
    aws cloudformation create-stack --stack-name CrossAccountAccessTerraform --capabilities CAPABILITY_NAMED_IAM --template-body file://cross-account-access-terraform.yaml
    awsume iam

    awsume training-alt
    aws cloudformation create-stack --stack-name CrossAccountAccessTerraform --capabilities CAPABILITY_NAMED_IAM --template-body file://cross-account-access-terraform.yaml
    awsume iam

Repeat for each of the other profiles `training-alt2` and `training-alt3`

To specify several `TrustRelationships`, add the parameters like this:

    --parameters ParameterKey=TrustRelationships,ParameterValue=<EXTERNALACCOUNT>\\,<IAMACCOUNT>

This is practical, if users outside `<IAMACCOUNT>` need to make changes via terraform.

To remove access to the alternate accounts again

    awsume training-alt
    aws cloudformation delete-stack --stack-name CrossAccountAccessTerraform
    awsume iam

Repeat for each of the other profiles `training-alt2` and `training-alt3`

## interact with the infrastructure

    awsume iam
    terraform init
    terraform workspace select training
    terraform plan
    terraform apply
    terraform output account_alias

## destroy the infrastructure

    awsume iam
    terraform destroy

This will give an error, but by now we know terraform and know that we just have to repeat `destroy` once more.

    aws_ram_principal_association.prod_transit_gateway_invite: Destruction complete after 3s
    ╷
    │ Error: deleting EC2 Transit Gateway Route Table Association (tgw-rtb-05807b3b1265eecad_tgw-attach-0c9a35e4becceba1c): IncorrectState: tgw-attach-0c9a35e4becceba1c is in invalid state
    │ 	status code: 400, request id: 1d908216-a874-47c4-ba84-0477e9fa8df7
    │

All in all it'll take about 5 minutes to destroy everything.

# isolated routing graph

Terraform can make graphs, but they are difficult to interpret

    brew install graphviz
    terraform graph | dot -Tsvg > graph.svg
        