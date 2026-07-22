#!/usr/bin/env bash

set -euo pipefail

kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"

if kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials >/dev/null 2>&1; then
  echo "ClickHouse credentials already exist"
  exit 0
fi

password="$(openssl rand -hex 16)"
kubectl --context "${kube_context}" --namespace data create secret generic clickhouse-credentials \
  --from-literal=username=localdev \
  --from-literal="password=${password}"

echo "Generated ClickHouse credentials in secret data/clickhouse-credentials"
