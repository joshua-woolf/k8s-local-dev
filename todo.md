Make the deployments production ready:
  - [ ] otel collector
  - [ ] elastic
Fix any warning or errors in pods where possible:
  - [ ] otel collector
  - [ ] elastic
Hook up apps to telemetry:
  - [ ] otel collector
  - [ ] elastic
Get elastic stack working.
Add dashboards to Grafana:
  - [text](https://grafana.com/grafana/dashboards/21875-opa-gatekeeper/)
  - [text](https://grafana.com/grafana/dashboards/22184-cert-manager2/)
  - [text](https://grafana.com/grafana/dashboards/9621-docker-registry/)
  - flagger
  - flagger load tester
  - otel collector
  - metrics server
Look at prometheus alerts.
Add local image cache.
Change entire setup to use flux for deployment.
Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.
Look at using a service mesh.
Look at adding network policies.
