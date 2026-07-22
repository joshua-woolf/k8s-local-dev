#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ca_root="${repo_root}/.state/mkcert"

mkdir -p "${ca_root}"
chmod 700 "${repo_root}/.state" "${ca_root}"

CAROOT="${ca_root}" mkcert -install
chmod 600 "${ca_root}/rootCA-key.pem"

echo "Trusted local CA: ${ca_root}/rootCA.pem"
