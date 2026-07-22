# Grafana dashboards

The dashboards are vendored so `make up` remains deterministic and does not need
Grafana.com or GitHub at deployment time. `sources.json` pins every upstream
revision and the checksum of the normalized local copy.

Upstream dashboards are normalized to use the provisioned Prometheus datasource
UID (`prometheus`) and are read-only in Grafana. Two compatibility adjustments
are deliberately maintained locally:

- The Strimzi broker variables use the standard `kubernetes_pod_name` label.
- The ClickHouse dashboard selects the local `namespace` and `pod` labels instead
  of ClickHouse Cloud's `service_name` and `control_plane_id` labels.
- Kubernetes Views uses current kube-state-metrics names for HPA and EndpointSlice
  inventory metrics.

The `custom` directory contains the small local overview, observability pipeline,
Gatekeeper, and application dashboards. These cover local concerns for which the
cluster does not have a suitable upstream dashboard.

To refresh an upstream dashboard, download the pinned source, run it through
`scripts/normalize-grafana-dashboard.jq`, reapply the compatibility adjustment if
needed, and update its SHA-256 value in `sources.json`.
