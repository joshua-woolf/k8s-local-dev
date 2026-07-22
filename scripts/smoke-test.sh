#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"
ca_file="${repo_root}/.state/mkcert/rootCA.pem"

kubectl --context "${kube_context}" wait --for=condition=Ready nodes --all --timeout=180s
kubectl --context "${kube_context}" --namespace dashboard rollout status deployment/dashboard --timeout=180s
kubectl --context "${kube_context}" --namespace observability rollout status deployment/otel-lgtm --timeout=300s
kubectl --context "${kube_context}" --namespace observability rollout status daemonset/alloy --timeout=180s
kubectl --context "${kube_context}" --namespace data rollout status statefulset/clickhouse --timeout=300s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready cluster/postgres --timeout=300s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready kafka/kafka --timeout=420s
kubectl --context "${kube_context}" --namespace dashboard wait --for=condition=Ready certificate/dashboard-tls --timeout=180s
kubectl --context "${kube_context}" --namespace observability wait --for=condition=Ready certificate/grafana-tls --timeout=180s

curl --fail --silent --show-error --cacert "${ca_file}" https://dashboard.k8s.localhost/healthz >/dev/null
curl --fail --silent --show-error --cacert "${ca_file}" https://grafana.k8s.localhost/api/health >/dev/null

if kubectl --context "${kube_context}" auth can-i get secrets \
  --as=system:serviceaccount:dashboard:dashboard --all-namespaces | grep -qx yes; then
  echo "Dashboard service account unexpectedly has Secret access" >&2
  exit 1
fi

kubectl --context "${kube_context}" --namespace data exec postgres-1 -- \
  psql --username postgres --dbname postgres --tuples-only --command 'SELECT 1' >/dev/null

clickhouse_user="$(kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials --output=jsonpath='{.data.username}' | base64 --decode)"
clickhouse_password="$(kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials --output=jsonpath='{.data.password}' | base64 --decode)"
kubectl --context "${kube_context}" --namespace data exec statefulset/clickhouse -- \
  clickhouse-client --user "${clickhouse_user}" --password "${clickhouse_password}" --query 'SELECT 1' >/dev/null

kafka_pod="$(kubectl --context "${kube_context}" --namespace data get pod \
  --selector=strimzi.io/name=kafka-kafka --output=jsonpath='{.items[0].metadata.name}')"
kubectl --context "${kube_context}" --namespace data exec "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic localdev-smoke --partitions 1 --replication-factor 1 >/dev/null
printf 'localdev-smoke\n' | kubectl --context "${kube_context}" --namespace data exec --stdin "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic localdev-smoke >/dev/null
kafka_result="$(kubectl --context "${kube_context}" --namespace data exec "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic localdev-smoke --from-beginning --max-messages 1 --timeout-ms 10000 2>/dev/null)"
test "${kafka_result}" = "localdev-smoke"

echo "Cluster smoke tests passed"
