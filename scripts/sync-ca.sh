#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ca_root="${repo_root}/.state/mkcert"
kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"

if [[ ! -s "${ca_root}/rootCA.pem" || ! -s "${ca_root}/rootCA-key.pem" ]]; then
  echo "Local CA not found. Run 'make trust' first." >&2
  exit 1
fi

kubectl --context "${kube_context}" wait \
  --namespace cert-manager \
  --for=condition=Available deployment/cert-manager \
  --timeout=180s

kubectl --context "${kube_context}" create secret tls local-dev-ca \
  --namespace cert-manager \
  --cert="${ca_root}/rootCA.pem" \
  --key="${ca_root}/rootCA-key.pem" \
  --dry-run=client \
  --output=yaml | kubectl --context "${kube_context}" apply -f -

kubectl --context "${kube_context}" apply \
  --filename "${repo_root}/manifests/cert-manager/cluster-issuer.yaml"
kubectl --context "${kube_context}" wait \
  --for=condition=Ready clusterissuer/local-dev-ca \
  --timeout=120s
