#!/bin/bash

# Generate a secure random key
TSIG_SECRET=$(openssl rand -base64 32)

# Update named.conf.local
sed -i.bak "s/secret \".*\";/secret \"${TSIG_SECRET}\";/" named.conf.local

# Update externaldns.yaml
sed -i.bak "s/--rfc2136-tsig-secret=.*/--rfc2136-tsig-secret=${TSIG_SECRET}/" externaldns.yaml

echo "TSIG key has been generated and configuration files have been updated."
echo "Secret: ${TSIG_SECRET}"
