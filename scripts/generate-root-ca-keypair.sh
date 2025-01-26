#!/bin/bash

if [ ! -f "../certs/ca.key" ] || [ ! -f "../certs/ca.crt" ]; then
  openssl genrsa -out "../certs/ca.key" 4096
  openssl req -x509 -new -nodes -key "../certs/ca.key" -sha256 -days 3650 -out "../certs/ca.crt" \
    -subj "/CN=Local Dev Root CA/O=Local Development/C=US"

  cat > "../certs/cluster-issuer.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
  namespace: cert-manager
data:
  tls.crt: $(base64 -i "../certs/ca.crt")
  tls.key: $(base64 -i "../certs/ca.key")
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
fi
