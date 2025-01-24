Make the deployments production ready:
  - [ ] bind9
  - [ ] external dns
  - [ ] otel collector
  - [ ] elastic
  - [ ] registry-ui
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
Get elastic stack working.
Hook up apps to telemetry:
  - [ ] bind9
  - [ ] external dns
  - [ ] otel collector
  - [ ] elastic
  - [ ] traefik
  - [ ] registry-ui
Add dashboards to Grafana.
Change entire setup to use flux for deployment.
Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.
Look at using a service mesh.
Look at adding network policies.
