#!/bin/bash

set -e

CA_DIR="$(dirname "$0")/ca"
mkdir -p "$CA_DIR"

if [ ! -f "$CA_DIR/ca.key" ] || [ ! -f "$CA_DIR/ca.crt" ]; then
  echo "Generating new Root CA key pair..."
  openssl genrsa -out "$CA_DIR/ca.key" 4096
  openssl req -x509 -new -nodes -key "$CA_DIR/ca.key" -sha256 -days 3650 -out "$CA_DIR/ca.crt" \
    -subj "/CN=Local Dev Root CA/O=Local Development/C=US"
else
  echo "Root CA already exists"
fi

# Trust the CA on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Installing Root CA to System Keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_DIR/ca.crt"
fi

# sudo security delete-certificate -c "Local Dev Root" /Library/Keychains/System.keychain

# Create cert-manager ClusterIssuer configuration
cat > "$CA_DIR/cluster-issuer.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
  namespace: cert-manager
data:
  tls.crt: $(base64 -i "$CA_DIR/ca.crt")
  tls.key: $(base64 -i "$CA_DIR/ca.key")
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF

echo "CA files generated in $CA_DIR"
echo "To regenerate the CA, delete the files in $CA_DIR and run this script again"
