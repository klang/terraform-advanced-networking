# /etc/ipsec.secrets
#

# This file holds shared secrets or RSA private keys for authentication.

# RSA private key for this host, authenticating it to any other host
# which knows the public part.
CONN1_TUNNEL1_ONPREM_OUTSIDE_IP CONN1_TUNNEL1_AWS_OUTSIDE_IP : PSK "CONN1_TUNNEL1_PresharedKey"
CONN1_TUNNEL2_ONPREM_OUTSIDE_IP CONN1_TUNNEL2_AWS_OUTSIDE_IP : PSK "CONN1_TUNNEL2_PresharedKey"