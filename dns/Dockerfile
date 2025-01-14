FROM ubuntu/bind9:latest

COPY named.conf.local /etc/bind/
COPY named.conf.options /etc/bind/
COPY local.dev.zone /etc/bind/zones/

RUN chmod 644 /etc/bind/named.conf.* /etc/bind/zones/*
