#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ca_root="${repo_root}/.state/mkcert"

if [[ ! -f "${ca_root}/rootCA.pem" ]]; then
  echo "No repository-local CA exists; nothing to untrust."
  exit 0
fi

CAROOT="${ca_root}" mkcert -uninstall
echo "Removed the local CA from host trust stores; CA files remain in .state/mkcert."
