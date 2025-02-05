#!/bin/bash

if [ ! -f "../certs/ca.key" ] || [ ! -f "../certs/ca.crt" ]; then
  openssl genrsa -out "../certs/ca.key" 4096
  openssl req -x509 -new -nodes -key "../certs/ca.key" -sha256 -days 3650 -out "../certs/ca.crt" \
    -subj "/CN=Local Dev Root CA/O=Local Development/C=US"
fi
