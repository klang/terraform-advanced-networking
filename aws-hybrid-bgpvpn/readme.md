# Advanced Demo - Site-To-Site VPN

[from Adrian Cantrill's course material](https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-hybrid-bgpvpn) .. [just released on youtube](https://www.youtube.com/watch?v=0dVVLKp4I18&t=1s)

# setup

    awsume training --region us-east-1
    terraform init
    terraform plan
    terraform apply

This will activate the [one click deployment of stack ADVANCEDVPNDEMO](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://learn-cantrill-labs.s3.amazonaws.com/aws-hybrid-bgpvpn/BGPVPNINFRA.yaml&stackName=ADVANCEDVPNDEMO) and apply all the changes needed.

## stage 1

### configuration files

Terraform will produce all the configuration files needed to complete the rest of the demo. Finishing the configuration by hand is part of the demo and I currently see no point in automating THAT part.

    connection1bgpconfig.txt
    connection1config.txt
    connection1ipsecconf.txt
    connection1ipsecsecrets.txt
    connection1ipsecvtish.txt

    connection2bgpconfig.txt
    connection2config.txt
    connection2ipsecconf.txt
    connection2ipsecsecrets.txt
    connection2ipsecvtish.txt


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

In the aws console, the tunnel status will still be "Down" as no BGP has been configured yet, but the Details will say "IPSEC IS UP".

## stage 4 (A and B)

Connect to `ONPREM-ROUTER1` and execute the following (do the same on `ONPREM-ROUTER2`) this will take 15-20 inutes

    sudo bash
    cd /home/ubuntu/demo_assets
    chmod +x ffrouting-install.sh
    ./ffrouting-install.sh

## stage 4 (C and D)


Paste the content of `connection1bgpconfig.txt` into the connection to `ONPREM-ROUTER1` and type `sudo reboot`
Paste the content of `connection2bgpconfig.txt` into the connection to `ONPREM-ROUTER2` and type `sudo reboot`

The routes advertised on the Transit Gateway will now contain the onprem servers and the site-2-site connection will show that both tunnels are up. Executing `route` on the onprem routers will show that they now know the aws servers.

Likewise, it's possible to `ping` any private ip address from any of the servers. The Transit Gateway uses the default route table and configure a "full mesh" in this example

# cleanup

    awsume training --region us-east-1
    terraform destroy

