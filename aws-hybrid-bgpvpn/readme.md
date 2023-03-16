# Advanced Demo - Site-To-Site VPN

[from Adrian Cantrill's course material](https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-hybrid-bgpvpn)

# setup

    awsume training --region us-east-1
    terraform init
    terraform plan
    terraform apply

This will activate the [one click deployment of stack ADVANCEDVPNDEMO](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://learn-cantrill-labs.s3.amazonaws.com/aws-hybrid-bgpvpn/BGPVPNINFRA.yaml&stackName=ADVANCEDVPNDEMO) and apply all the changes needed.

## stage 1

### confirm no connectivity

    aws ec2 describe-instances --filters "Name=tag-value,Values=ONPREM-SERVER2" --region us-east-1 --query "Reservations[].Instances[] | [? NetworkInterfaces ].{InstanceId:InstanceId}" --output text

    server2=$(aws ec2 describe-instances --filters "Name=tag-value,Values=ONPREM-SERVER2" --region us-east-1 --query "Reservations[].Instances[] | [? NetworkInterfaces ].{InstanceId:InstanceId}" --output text)

aws ssm start-session --target=$server2 --document-name AWS-StartSSHSession --parameters 'portNumber=22'

# .ssh/config

    # SSH over Session Manager
    # brew install --cask session-manager-plugin
    #host i-* mi-*
    #    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"

    host i-* mi-*
        User                   ubuntu
        IdentityFile           ~/.ssh/systime.pem
        ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"



    aws ec2 describe-instances --filters "Name=tag-value,Values=ONPREM-ROUTER1" --region us-east-1 --query "Reservations[].Instances[] | [? NetworkInterfaces ].{InstanceId:InstanceId}" --output text


    router1=$(aws ec2 describe-instances --filters "Name=tag-value,Values=ONPREM-ROUTER1" --region us-east-1 --query "Reservations[].Instances[] | [? NetworkInterfaces ].{InstanceId:InstanceId}" --output text)


    aws ssm start-session --target=$router1 --document-name AWS-StartSSHSession --parameters 'portNumber=22'


## stage 3

    sudo bash
    cd /home/ubuntu/demo_assets

    # for each of the following 3, fetch the appropriate configuration{1,2}ipsec{secrets,conf,vitsh}.txt file and paste them into `vi`
    rm ipsec.conf; vi ipsec.conf
    rm ipsec.secrets; vi ipsec.secrets
    rm ipsec-vti.sh; vi ipsec-vti.sh
    chown ubuntu:ubuntu ipsec*
    cp ipsec* /etc
    chmod +x /etc/ipsec-vti.sh

    systemctl restart strongswan
    ifconfig

ifconfig should have vti1 and vti2 onthe list of interfaces

# cleanup

    awsume training --region us-east-1
    terraform destroy

