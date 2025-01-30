#!/bin/bash

set -euo pipefail

# Configuration
LOCAL_REGISTRY="localhost:5001"
LOG_FILE="image-cache.log"

# Function to log messages
log() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

# Function to process a single image
process_image() {
  local source_image="$1"

  local target_image="$LOCAL_REGISTRY/$source_image"

  log "Processing image: $source_image"

  # Pull the image
  if ! docker pull "$source_image"; then
    log "ERROR: Failed to pull $source_image"
    return 1
  fi

  # Tag the image
  if ! docker tag "$source_image" "$target_image"; then
    log "ERROR: Failed to tag $source_image as $target_image"
    return 1
  fi

  # Push the image
  if ! docker push "$target_image"; then
    log "ERROR: Failed to push $target_image"
    return 1
  fi

  log "Successfully processed: $source_image -> $target_image"
  return 0
}

main() {
  log "Starting image caching process"

  # Create fresh log file
  > "$LOG_FILE"

  # Check if docker is running
  if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker is not running"
    exit 1
  fi

  # Check if we can reach the local registry
  if ! curl -s "http://$LOCAL_REGISTRY/v2/" >/dev/null; then
    log "ERROR: Cannot reach local registry at $LOCAL_REGISTRY"
    exit 1
  fi

  # Define the list of images to cache
  declare -a IMAGES=(
    "ubuntu/bind9:9.18-22.04_beta"
    "registry.k8s.io/external-dns/external-dns:v0.15.1"
    "docker.elastic.co/eck/eck-operator:2.16.1"
    "docker.elastic.co/elasticsearch/elasticsearch:8.17.0"
    "docker.elastic.co/kibana/kibana:8.17.0"
    "docker.elastic.co/apm/apm-server:8.17.0"
    "docker.elastic.co/beats/elastic-agent:8.17.0"
    "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
    "joxit/docker-registry-ui:2.5.2"
    "docker.io/traefik:v3.3.2"
    "openpolicyagent/gatekeeper:v3.18.2"
    "ghcr.io/fluxcd/flagger:1.40.0"
    "ghcr.io/fluxcd/flagger-loadtester:0.34.0"
    "quay.io/jetstack/cert-manager-cainjector:v1.16.3"
    "quay.io/jetstack/cert-manager-controller:v1.16.3"
    "quay.io/jetstack/cert-manager-webhook:v1.16.3"
    "ghcr.io/stefanprodan/podinfo:6.1.4"
    "quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2"
    "quay.io/prometheus/prometheus:v3.1.0"
    "quay.io/prometheus/node-exporter:v1.8.2"
    "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"
    "quay.io/prometheus-operator/prometheus-operator:v0.79.2"
    "quay.io/kiwigrid/k8s-sidecar:1.28.0"
    "docker.io/library/busybox:1.31.1"
    "docker.io/grafana/grafana:11.4.0"
    "otel/opentelemetry-collector-k8s:0.117.0"
    "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.1"
  )

  # Process each image
  local success_count=0
  local fail_count=0

  for image in "${IMAGES[@]}"; do
    if process_image "$image"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done

  log "Cache process completed"
  log "Successfully processed: $success_count images"
  log "Failed to process: $fail_count images"

  if [ "$fail_count" -gt 0 ]; then
    log "Check $LOG_FILE for details on failures"
    exit 1
  fi
}

main "$@"

