#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"
namespace="observability"
dashboard_root="${repo_root}/manifests/observability/dashboards"

for group in custom kubernetes platform data; do
  kubectl --context "${context}" --namespace "${namespace}" create configmap "grafana-dashboards-${group}" \
    --from-file="${dashboard_root}/${group}" \
    --dry-run=client \
    --output=yaml | kubectl --context "${context}" apply --server-side --field-manager=local-dev-dashboards --filename=-
done
