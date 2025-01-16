FROM ubuntu/bind9:latest

COPY named.conf.local /etc/bind/
COPY named.conf.options /etc/bind/

COPY local.dev.zone /var/cache/bind/
