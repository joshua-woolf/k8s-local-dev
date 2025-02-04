Improve k8s-dashboard:
  - Add credentials.
  - Add telemetry.
  - Add canary.
  - Add tests.
  - Refactor.
  -

Look at Kubernetes Dashboard:
https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

Refactor scripts.
Add keda.

Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.

Change entire setup to use flux for deployment.
Convert script to powershell.

Add dashboards to Grafana for flagger and load tester.
Refine dashboards.

Make the repository presentable.

Future enhancements:
  - mTLS
  - Network Policies
  - Resource Requests and Limits
  - Secure Connections
  - Service Mesh
  - Storage
