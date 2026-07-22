#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"

kubectl --context "${kube_context}" wait \
  --namespace gatekeeper-system \
  --for=condition=Available deployment/gatekeeper-controller-manager \
  --timeout=180s
kubectl --context "${kube_context}" apply \
  --filename "${repo_root}/manifests/policies/templates.yaml"

for crd in \
  k8srequiredresources.constraints.gatekeeper.sh \
  k8snoprivilegedcontainers.constraints.gatekeeper.sh \
  k8spinnedimages.constraints.gatekeeper.sh; do
  kubectl --context "${kube_context}" wait \
    --for=condition=Established "crd/${crd}" \
    --timeout=120s
done

kubectl --context "${kube_context}" apply \
  --filename "${repo_root}/manifests/policies/constraints.yaml"
