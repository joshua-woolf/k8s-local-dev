#!/bin/bash

LOCAL_REGISTRY="localhost:5001"

declare -a IMAGES=(
  "curlimages/curl:7.83.1"
  "docker.elastic.co/eck/eck-operator:2.16.1"
  "docker.elastic.co/elasticsearch/elasticsearch:8.17.0"
  "docker.elastic.co/kibana/kibana:8.17.0"
  "docker.elastic.co/apm/apm-server:8.17.0"
  "docker.elastic.co/beats/elastic-agent:8.17.0"
  "docker.io/busybox:1.37.0"
  "docker.io/grafana/grafana:11.4.0"
  "docker.io/library/busybox:1.31.1"
  "docker.io/traefik:v3.3.2"
  "ghcr.io/fluxcd/flagger:1.40.0"
  "ghcr.io/fluxcd/flagger-loadtester:0.34.0"
  "ghcr.io/stefanprodan/podinfo:6.7.1"
  "joxit/docker-registry-ui:2.5.2"
  "openpolicyagent/gatekeeper:v3.18.2"
  "openpolicyagent/gatekeeper-crds:v3.18.2"
  "otel/opentelemetry-collector-k8s:0.117.0"
  "prometheuscommunity/bind-exporter:v0.6.0"
  "quay.io/jetstack/cert-manager-acmesolver:v1.16.3"
  "quay.io/jetstack/cert-manager-cainjector:v1.16.3"
  "quay.io/jetstack/cert-manager-controller:v1.16.3"
  "quay.io/jetstack/cert-manager-startupapicheck:v1.16.3"
  "quay.io/jetstack/cert-manager-webhook:v1.16.3"
  "quay.io/kiwigrid/k8s-sidecar:1.28.0"
  "quay.io/prometheus/node-exporter:v1.8.2"
  "quay.io/prometheus/prometheus:v3.1.0"
  "quay.io/prometheus-operator/admission-webhook:v0.79.2"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2"
  "quay.io/prometheus-operator/prometheus-operator:v0.79.2"
  "registry.k8s.io/external-dns/external-dns:v0.15.1"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.1"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"
  "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
  "ubuntu/bind9:9.18-22.04_beta"
)

for source_image in "${IMAGES[@]}"; do
  target_image="$LOCAL_REGISTRY/$source_image"
  if ! curl -s -f -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.oci.image.manifest.v2+json" "https://$LOCAL_REGISTRY/v2/${source_image%:*}/manifests/${source_image#*:}" >/dev/null 2>&1; then
    echo "Processing image: $source_image"

    docker pull "$source_image"
    docker run -v "/var/run/docker.sock:/var/run/docker.sock" -v "$HOME/Library/Caches:/root/.cache/" ghcr.io/aquasecurity/trivy:0.59.0 image "$source_image"
    docker tag "$source_image" "$target_image"
    docker push "$target_image"
  fi
done
