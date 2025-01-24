Change bind9 to use a service monitor.
Add waits for pods to be ready:
  - [ ] bind9
  - [ ] external dns
Make the deployments production ready:
  - [ ] otel collector
  - [ ] elastic
Fix any warning or errors in pods where possible:
  - [ ] otel collector
  - [ ] elastic
Label and annotate all resources:
  - [ ] cert manager
  - [ ] bind9
  - [ ] external dns
  - [ ] metrics server
  - [ ] gatekeeper
  - [ ] otel collector
  - [ ] elastic
  - [ ] podinfo
  - [ ] prometheus
  - [ ] grafana
  - [ ] traefik
  - [ ] registry-ui
  - [ ] flagger
  - [ ] flagger-loadtester
Hook up apps to telemetry:
  - [ ] otel collector
  - [ ] elastic
Get elastic stack working.
Add dashboards to Grafana.
Look at prometheus alerts.
Change entire setup to use flux for deployment.
Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.
Look at using a service mesh.
Look at adding network policies.
