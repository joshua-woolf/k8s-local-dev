#!/usr/bin/env bash

set -euo pipefail

kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"

if kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials >/dev/null 2>&1; then
  echo "ClickHouse credentials already exist"
else
  clickhouse_password="$(openssl rand -hex 16)"
  kubectl --context "${kube_context}" --namespace data create secret generic clickhouse-credentials \
    --from-literal=username=localdev \
    --from-literal="password=${clickhouse_password}"

  echo "Generated ClickHouse credentials in secret data/clickhouse-credentials"
fi

if kubectl --context "${kube_context}" --namespace data get secret pgadmin-credentials >/dev/null 2>&1; then
  echo "pgAdmin credentials already exist"
else
  pgadmin_password="$(openssl rand -hex 16)"
  kubectl --context "${kube_context}" --namespace data create secret generic pgadmin-credentials \
    --from-literal="password=${pgadmin_password}"

  echo "Generated pgAdmin credentials in secret data/pgadmin-credentials"
fi
