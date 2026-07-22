# Kubernetes Local Dev

A deliberately small, single-node Kubernetes development environment built on
[Kind](https://kind.sigs.k8s.io/). It provides local HTTPS ingress, an
observability backend, common data services, optional policy checks, and a small
dashboard without modifying host DNS settings.

## What runs

The core profile contains:

- Traefik for standard Kubernetes `Ingress` resources
- cert-manager with a repository-local development CA
- Grafana Alloy for pod logs, annotated Prometheus metrics, and OTLP
- `grafana/otel-lgtm` with Grafana, Loki, Tempo, Prometheus, and Pyroscope
- CloudNativePG with one PostgreSQL instance
- pgAdmin with the local PostgreSQL connection preconfigured
- The local service dashboard

The full profile additionally contains:

- A single-node ClickHouse StatefulSet
- A single combined Strimzi KRaft controller/broker
- Kafbat UI connected to the local Kafka broker
- A persistent single-node Valkey instance
- Valkey Admin connected to the local Valkey instance
- Gatekeeper with warning-only policies for application namespaces

This is a disposable development environment. It is not a production topology:
databases have one replica, Gatekeeper does not enforce, and the LGTM container
is intended for development and testing.

## Host access

Names beneath `.localhost` resolve to loopback without Bind9, ExternalDNS, or
changes to macOS network configuration:

| Service | Address |
| --- | --- |
| Dashboard | `https://dashboard.k8s.localhost` |
| Grafana | `https://grafana.k8s.localhost` |
| pgAdmin | `https://pgadmin.k8s.localhost` |
| Kafbat UI | `https://kafbat.k8s.localhost` |
| Valkey Admin | `https://valkey-ui.k8s.localhost` |
| PostgreSQL | `postgres.k8s.localhost:5432` |
| ClickHouse HTTP | `https://clickhouse.k8s.localhost` or `clickhouse.k8s.localhost:8123` |
| ClickHouse native | `clickhouse.k8s.localhost:9000` |
| Kafka | `kafka.k8s.localhost:9094` |
| Valkey | `valkey.k8s.localhost:6379` |

Kind maps every listed port to a fixed Traefik NodePort. Traefik uses normal
HTTP routing for the web applications and dedicated TCP entrypoints for each
data protocol. Every mapped port listens only on `127.0.0.1`.

## Prerequisites

This project targets macOS with Docker Desktop. Allocate at least 8 GB to
Docker for the core profile and 10–12 GB for the full profile.

Install the tools in the Brewfile:

```sh
brew bundle
```

The important commands are Docker, Kind, kubectl, Helm, Helmfile, mkcert,
kubeconform, Node.js, and shellcheck. The browser smoke test uses an installed
Google Chrome by default.

## Quick start

Trust the dedicated repository CA. This is the only command that changes the
host trust store and macOS may ask for confirmation:

```sh
make trust
```

Create the core cluster:

```sh
make up-core
```

Or create the full cluster:

```sh
make up
```

Open `https://dashboard.k8s.localhost`. Both setup commands are safe to rerun;
they reconcile charts and manifests and reload the locally built dashboard.

Kind host-port mappings are immutable. If you already have a cluster created by
an older revision that did not expose the data ports, recreate it once:

```sh
make reset CONFIRM=1
make up
```

This deletes every PVC in that local cluster.

## Commands

| Command | Purpose |
| --- | --- |
| `make doctor` | Check tools and Docker availability |
| `make trust` | Generate and install this repository's mkcert CA |
| `make untrust` | Remove that CA from host trust stores |
| `make up-core` | Reconcile the lightweight profile |
| `make up` | Reconcile the full profile |
| `make dashboard` | Rebuild, load, and redeploy the dashboard |
| `make load IMAGE=example/app:dev` | Load another local image into Kind |
| `make ports` | Print data-service host endpoints |
| `make credentials` | Print generated UI and data-service credentials |
| `make status` | Show nodes, Helm releases, pods, and ingresses |
| `make test` | Run dashboard lint and unit tests |
| `make validate` | Render and schema-check every deployment input |
| `make smoke` | Test the running cluster and dashboard in Chrome |
| `make reset CONFIRM=1` | Delete the cluster and every local PVC |

Kind does not have a useful stop/start lifecycle. Leave the cluster running or
delete and recreate it. `make reset` does not remove the trusted CA; use
`make untrust` separately.

## TLS model

`make trust` sets `CAROOT` to `.state/mkcert`, generates a dedicated CA, and
installs only that root certificate in host trust stores. `.state/` is ignored
by Git and the private key is mode `0600`.

During `make up`, the CA pair is synchronized into a `local-dev-ca` TLS Secret
in the cert-manager namespace. The `local-dev-ca` ClusterIssuer signs a separate
leaf certificate for each Ingress. Ingresses request certificates with:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: local-dev-ca
spec:
  tls:
    - hosts:
        - example.k8s.localhost
      secretName: example-tls
```

Never commit `.state/mkcert/rootCA-key.pem`. A copy of that key can impersonate
any site to a machine that trusts the CA.

Node clients do not always consult the macOS trust store. For a Node process,
set `NODE_EXTRA_CA_CERTS="$PWD/.state/mkcert/rootCA.pem"`.

cert-manager certificates cover the HTTPS endpoints on port 443. The dedicated
TCP entrypoints on 5432, 6379, 8123, 9000, and 9094 are passed through to their
services and are not TLS-terminated by cert-manager. They remain loopback-only.

## Dashboard discovery

The dashboard reads only Ingresses, Services, and EndpointSlices. Its service
account cannot read Secrets.

Resources are opt-in. Add annotations such as:

```yaml
metadata:
  annotations:
    localdev.dashboard/enabled: "true"
    localdev.dashboard/name: Example API
    localdev.dashboard/category: Applications
    localdev.dashboard/description: Example service used during development
```

Annotated Ingresses become HTTPS links. Annotated Services receive cluster DNS
and port-forward instructions. A service that has permanent host access can
also provide `localdev.dashboard/host`, `localdev.dashboard/port`, and
`localdev.dashboard/protocol` annotations.

## Local application images

Use a real non-`latest` tag and load the image directly:

```sh
docker build -t example-api:dev-1 .
make load IMAGE=example-api:dev-1
```

Set `imagePullPolicy: IfNotPresent` in the workload. There is no local registry,
registry certificate, mirror, or image-cache synchronization loop.

## Data services

Display all generated local credentials:

```sh
make credentials
```

pgAdmin uses the generated login at `https://pgadmin.k8s.localhost`. The
`Local PostgreSQL` server is preloaded with the `app` database and retrieves its
password from CloudNativePG's `postgres-app` Secret. Kafbat requires no login in
this loopback-only setup and connects to Kafka through the internal listener.
Valkey Admin requires no separate UI login and receives its preconfigured
connection from the generated `valkey-credentials` Secret.

PostgreSQL clients connect to `postgres.k8s.localhost:5432`. ClickHouse clients
can use HTTPS on port 443, plain HTTP on 8123, or the native protocol on 9000.
Kafka clients use `kafka.k8s.localhost:9094`; the single broker advertises that
same endpoint. Valkey clients use `valkey.k8s.localhost:6379`, the `default`
user, and the generated password printed by `make credentials`. The raw Valkey
connection is not TLS-encrypted and is deliberately bound to loopback only.

Deleting the Kind cluster deletes all PVC data. Keep schema migrations and seed
steps reproducible rather than treating this cluster as a backup.

## Profiles and policy

The dashboard namespace carries `policy.localdev/enabled: "true"`. Gatekeeper
constraints match only namespaces with that label and currently warn about:

- Missing CPU or memory requests and limits
- Privileged containers
- Images without an explicit tag/digest, or images using `latest`

System, controller, observability, and data namespaces are excluded. Move a
constraint from `warn` to `deny` only after existing application workloads pass.

## Troubleshooting

Check the overall state:

```sh
make status
kubectl get certificate,certificaterequest -A
kubectl get events -A --sort-by=.lastTimestamp
```

If ports 80, 443, 5432, 6379, 8123, 9000, or 9094 are occupied, Kind cannot create
the node. Stop the conflicting process before retrying.

If an older checkout of this repository is still running, use that checkout's
legacy teardown before creating v2. The old setup changed the active network's
DNS servers and installed a different system CA. Teardown deletes the old Kind
cluster and all of its local data.
