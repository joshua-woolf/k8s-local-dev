Make the deployments production ready:
  - [ ] otel collector
  - [ ] elastic
Fix any warning or errors in pods where possible:
  - [ ] otel collector
  - [ ] elastic
Hook up apps to telemetry:
  - [ ] otel collector
  - [ ] elastic
Add dashboards to Grafana:
  - flagger
  - flagger load tester
  - otel collector
Look at prometheus alerts.
Look at getting elastic TLS working.
Look at getting alert manager working.
Add local image cache.
Change entire setup to use flux for deployment.
Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.
Look at using a service mesh.
Look at adding network policies.
Create dashboard app.
Cleanup yaml formatting.
