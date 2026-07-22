#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kube_context="${KUBE_CONTEXT:-kind-${CLUSTER_NAME:-local-dev}}"
ca_file="${repo_root}/.state/mkcert/rootCA.pem"

kubectl --context "${kube_context}" wait --for=condition=Ready nodes --all --timeout=180s
kubectl --context "${kube_context}" --namespace dashboard rollout status deployment/dashboard --timeout=180s
kubectl --context "${kube_context}" --namespace observability rollout status deployment/otel-lgtm --timeout=300s
kubectl --context "${kube_context}" --namespace observability rollout status daemonset/alloy --timeout=180s
kubectl --context "${kube_context}" --namespace data rollout status deployment/pgadmin --timeout=300s
kubectl --context "${kube_context}" --namespace data rollout status statefulset/clickhouse --timeout=300s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready cluster/postgres --timeout=300s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready kafka/kafka --timeout=420s
kubectl --context "${kube_context}" --namespace data rollout status deployment/kafbat --timeout=300s
kubectl --context "${kube_context}" --namespace data rollout status statefulset/valkey --timeout=300s
kubectl --context "${kube_context}" --namespace data rollout status deployment/valkey-admin --timeout=300s
kubectl --context "${kube_context}" --namespace dashboard wait --for=condition=Ready certificate/dashboard-tls --timeout=180s
kubectl --context "${kube_context}" --namespace observability wait --for=condition=Ready certificate/grafana-tls --timeout=180s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready certificate/pgadmin-tls --timeout=180s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready certificate/kafbat-tls --timeout=180s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready certificate/clickhouse-http-tls --timeout=180s
kubectl --context "${kube_context}" --namespace data wait --for=condition=Ready certificate/valkey-admin-tls --timeout=180s

curl --fail --silent --show-error --cacert "${ca_file}" https://dashboard.k8s.localhost/healthz >/dev/null
curl --fail --silent --show-error --cacert "${ca_file}" https://grafana.k8s.localhost/api/health >/dev/null
curl --fail --silent --show-error --cacert "${ca_file}" https://pgadmin.k8s.localhost/misc/ping >/dev/null
curl --fail --silent --show-error --cacert "${ca_file}" https://kafbat.k8s.localhost/actuator/health >/dev/null
curl --fail --silent --show-error --cacert "${ca_file}" https://valkey-ui.k8s.localhost/ >/dev/null
test "$(curl --fail --silent --show-error --cacert "${ca_file}" \
  https://kafbat.k8s.localhost/api/clusters | jq --raw-output '.[0].status')" = "ONLINE"

grafana_dashboards="$(curl --fail --silent --show-error --cacert "${ca_file}" \
  'https://grafana.k8s.localhost/api/search?tag=local-dev')"
for dashboard_uid in \
  localdev-applications \
  localdev-cert-manager \
  localdev-clickhouse \
  localdev-gatekeeper \
  localdev-kafka \
  localdev-kubernetes \
  localdev-observability \
  localdev-postgres \
  localdev-traefik \
  localdev-valkey; do
  test "$(jq --arg uid "${dashboard_uid}" '[.[] | select(.uid == $uid)] | length' <<<"${grafana_dashboards}")" = "1"
done

prometheus_query() {
  kubectl --context "${kube_context}" --namespace observability exec deployment/otel-lgtm -- \
    curl --fail --silent --show-error --get http://127.0.0.1:9090/api/v1/query \
      --data-urlencode "query=$1"
}

for metrics_job in \
  alloy \
  cadvisor \
  cert-manager \
  clickhouse \
  cloudnative-pg \
  gatekeeper \
  grafana \
  kafbat \
  kafka \
  kube-state-metrics \
  kubelet \
  loki \
  postgresql \
  prometheus \
  pyroscope \
  tempo \
  traefik \
  valkey; do
  query_result="$(prometheus_query "up{job=\"${metrics_job}\"} == 1")"
  test "$(jq '.data.result | length' <<<"${query_result}")" -gt 0
done

if kubectl --context "${kube_context}" auth can-i get secrets \
  --as=system:serviceaccount:dashboard:dashboard --all-namespaces | grep -qx yes; then
  echo "Dashboard service account unexpectedly has Secret access" >&2
  exit 1
fi

test "$(kubectl --context "${kube_context}" --namespace data auth can-i get \
  secret/valkey-credentials --as=system:serviceaccount:dashboard:dashboard)" = "yes"
test "$(kubectl --context "${kube_context}" --namespace data auth can-i list \
  secrets --as=system:serviceaccount:dashboard:dashboard)" = "no"
test "$(kubectl --context "${kube_context}" --namespace observability auth can-i get \
  secret/grafana-tls --as=system:serviceaccount:dashboard:dashboard)" = "no"

kubectl --context "${kube_context}" --namespace data exec postgres-1 -- \
  psql --username postgres --dbname postgres --tuples-only --command 'SELECT 1' >/dev/null

clickhouse_user="$(kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials --output=jsonpath='{.data.username}' | base64 --decode)"
clickhouse_password="$(kubectl --context "${kube_context}" --namespace data get secret clickhouse-credentials --output=jsonpath='{.data.password}' | base64 --decode)"
kubectl --context "${kube_context}" --namespace data exec statefulset/clickhouse -- \
  clickhouse-client --user "${clickhouse_user}" --password "${clickhouse_password}" --query 'SELECT 1' >/dev/null
test "$(curl --fail --silent --show-error --cacert "${ca_file}" \
  --user "${clickhouse_user}:${clickhouse_password}" \
  --data-binary 'SELECT 1' https://clickhouse.k8s.localhost/)" = "1"
test "$(curl --fail --silent --show-error \
  --user "${clickhouse_user}:${clickhouse_password}" \
  --data-binary 'SELECT 1' http://clickhouse.k8s.localhost:8123/)" = "1"

kafka_pod="$(kubectl --context "${kube_context}" --namespace data get pod \
  --selector=strimzi.io/name=kafka-kafka --output=jsonpath='{.items[0].metadata.name}')"
kubectl --context "${kube_context}" --namespace data exec "${kafka_pod}" -- \
  grep -q 'EXTERNAL-9094://kafka.k8s.localhost:9094' /tmp/strimzi.properties
kubectl --context "${kube_context}" --namespace data exec "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic localdev-smoke --partitions 1 --replication-factor 1 >/dev/null
printf 'localdev-smoke\n' | kubectl --context "${kube_context}" --namespace data exec --stdin "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic localdev-smoke >/dev/null
kafka_result="$(kubectl --context "${kube_context}" --namespace data exec "${kafka_pod}" -- \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic localdev-smoke --from-beginning --max-messages 1 --timeout-ms 10000 2>/dev/null)"
test "${kafka_result}" = "localdev-smoke"

valkey_password="$(kubectl --context "${kube_context}" --namespace data get secret valkey-credentials --output=jsonpath='{.data.password}' | base64 --decode)"
kubectl --context "${kube_context}" --namespace data exec statefulset/valkey -- \
  env "VALKEYCLI_AUTH=${valkey_password}" valkey-cli SET localdev-smoke ready >/dev/null
valkey_result="$(kubectl --context "${kube_context}" --namespace data exec statefulset/valkey -- \
  env "VALKEYCLI_AUTH=${valkey_password}" valkey-cli GET localdev-smoke)"
test "${valkey_result}" = "ready"

for endpoint in \
  postgres.k8s.localhost:5432 \
  clickhouse.k8s.localhost:8123 \
  clickhouse.k8s.localhost:9000 \
  kafka.k8s.localhost:9094 \
  valkey.k8s.localhost:6379; do
  host="${endpoint%:*}"
  port="${endpoint##*:}"
  nc -z -w 5 "${host}" "${port}"
done

kubectl --context "${kube_context}" --namespace data exec deployment/pgadmin -- \
  test -r /run/secrets/postgres/password
pgadmin_server="$(kubectl --context "${kube_context}" --namespace data exec deployment/pgadmin -- \
  python3 -c "import sqlite3; db=sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); print(db.execute('select host from server where name = ?', ('Local PostgreSQL',)).fetchone()[0])")"
test "${pgadmin_server}" = "postgres-rw.data.svc.cluster.local"

echo "Cluster smoke tests passed"
