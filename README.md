# Kubernetes Local Dev

## Overview

This repository contains a baseline setup of a Kubernetes cluster for local development and an example dashboard application that displays information on the applications running inside the cluster.

The dashboard can be locally built and deployed to the cluster and includes canary deployments, OpenTelemetry integration and smoke tests to verify that the application is working as expected when deployed.

The baseline includes:
- Kubernetes:
  - [Kind Cluster](https://kind.sigs.k8s.io)
- Container Registry:
  - [Distribution Registry](https://distribution.github.io/distribution)
  - [Registry UI](https://github.com/Joxit/docker-registry-ui)
- DNS:
  - [Bind9](https://bind9.net)
  - [External DNS](https://kubernetes-sigs.github.io/external-dns)
- Ingress:
  - [Traefik](https://traefik.io/traefik)
  - [Cert Manager](https://cert-manager.io)
- Observability:
  - [Metrics Server](https://kubernetes-sigs.github.io/metrics-server)
  - [Prometheus](https://prometheus.io)
  - [Grafana](https://grafana.com)
  - [Elastic Stack](https://www.elastic.co/guide/en/cloud-on-k8s/current)
  - [OpenTelemetry Collector](https://opentelemetry.io/docs/collector)
- Progressive Delivery:
  - [Flagger](https://flagger.app)
- Other:
  - [Gatekeeper](https://open-policy-agent.github.io/gatekeeper)
  - [KEDA](https://keda.sh)

All of the container images are scanned using [Trivy](https://trivy.dev) and cached in the local container registry to speed up cluster provisioning between changes.

## Prerequisites

Since this is a hobby project, it hasn't been built with cross-platform compatibility in mind.

There are some commands specific to macOS used in the setup and teardown scripts, so it would take some effort to get this working on other platforms. I run this on a Mac M4 Pro and have included a [Brewfile](./Brewfile) with the dependencies I used when working on this project.

You can install [Homebrew](https://brew.sh) and the dependencies with the following commands:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew bundle
```

You may need to allow execution of the scripts by running the following command:

```bash
chmod +x ./setup.sh
chmod +x ./teardown.sh
```

## Getting Started

*⚠️ Before running the project it's a good idea to understand what the setup is going to do as it will need to change some of your host machine's configuration to trust a generated root CA certificate and modify DNS settings on your active network. This is done to enable secure access services running inside the cluster from your host machine with working DNS and TLS. When running the scripts you may be prompted to enter your password for elevated privileges. The teardown script will revert the changes made.*

To setup the cluster, you can run the following command:

```bash
./setup.sh
```

To teardown the cluster, you can run the following command:

```bash
./teardown.sh
```

## Troubleshooting

There is sometimes an issue where the DNS cache on the host machine needs to be flushed if names are not resolving. You can flush the cache with the following commands:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```
