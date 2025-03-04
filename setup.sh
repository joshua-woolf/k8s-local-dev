#!/bin/bash

set -e

mkdir -p "./temp"

# Helm Repos
helm repo add elastic https://helm.elastic.co
helm repo add flagger https://flagger.app
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add joxit https://helm.joxit.dev
helm repo add keda https://kedacore.github.io/charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts

helm repo update elastic flagger gatekeeper jetstack joxit keda metrics-server open-telemetry prometheus-community traefik

# Scan all Helm charts
mkdir -p "./logs/trivy/helm-charts"

LOCAL_CHARTS=()
while IFS= read -r chart; do
  LOCAL_CHARTS+=("$chart")
done < <(find charts -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

for chart in "${LOCAL_CHARTS[@]}"; do
  echo "Scanning Helm chart: $chart"

  docker run --rm \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    -v "$HOME/Library/Caches:/root/.cache/" \
    -v "$(pwd):/workspace" \
    -w /workspace \
    ghcr.io/aquasecurity/trivy:0.59.0 \
    config --ignorefile "/workspace/charts/${chart}/.trivyignore" "/workspace/charts/${chart}" > "./logs/trivy/helm-charts/${chart}.log"
done

# Trusted Root CA Certificate
mkdir -p "./temp/secrets"

if [ ! -f "./temp/secrets/ca.key" ] || [ ! -f "./temp/secrets/ca.crt" ]; then
  echo "Generating Root CA..."
  openssl genrsa -out "./temp/secrets/ca.key" 4096
  openssl req -x509 -new -nodes -key "./temp/secrets/ca.key" -sha256 -days 3650 -out "./temp/secrets/ca.crt" \
    -subj "/CN=Local Dev Root CA/O=Local Development/C=US"
  sudo chmod +r "./temp/secrets/ca.key"
fi

if ! security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  echo "Installing Root CA to System Keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "./temp/secrets/ca.crt"
fi

# TSIG Key
if [ ! -f "./temp/secrets/tsig.key" ]; then
  openssl rand -base64 32 > "./temp/secrets/tsig.key"
fi

TSIG_KEY=$(cat "./temp/secrets/tsig.key")

# Create Registry Certificate Private Key
openssl genrsa -out "./temp/secrets/registry.key" 2048

# Create Registry Certificate Signing Request
openssl req -new \
  -key "./temp/secrets/registry.key" \
  -config "./configs/certificate-authority/registry.conf" \
  -out "./temp/secrets/registry.csr"

sudo chmod +r "./temp/secrets/registry.key"

# Sign the Registry Certificate with the Certificate Authority
openssl x509 -req \
  -in "./temp/secrets/registry.csr" \
  -CA "./temp/secrets/ca.crt" \
  -CAkey "./temp/secrets/ca.key" \
  -CAcreateserial \
  -out "./temp/secrets/registry.crt" \
  -days 365 \
  -sha256 \
  -extfile "./configs/certificate-authority/registry-signing.conf" \
  -extensions v3_ext

# Container Registry
mkdir -p "./temp/registry-cache"

if ! docker network ls | grep -q kind; then
  docker network create kind
fi

if docker ps -f name=registry | grep -q registry; then
  echo "Registry Container Already Running..."
else
  docker run -d --restart=always \
    -v ./temp/secrets:/certs \
    -v ./temp/registry-cache:/var/lib/registry \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers='["Authorization", "Accept", "Cache-Control"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods='["DELETE", "GET", "HEAD", "OPTIONS"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin='["https://registry.local.dev"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers='["Docker-Content-Digest"]' \
    -e "REGISTRY_HTTP_SECRET=$(openssl rand -hex 32)" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
    -e REGISTRY_LOG_FORMATTER=json \
    -e REGISTRY_LOG_LEVEL=info \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true \
    -p 5001:443 --name registry --network kind registry:2.8.3@sha256:319881be2ee9e345d5837d15842a04268de6a139e23be42654fc7664fc6eaf52
fi

# Image Caching
LOCAL_REGISTRY="localhost:5001"

declare -a IMAGES=(
  "curlimages/curl:8.12.1"
  "docker.elastic.co/eck/eck-operator:2.16.1"
  "docker.elastic.co/elasticsearch/elasticsearch:8.17.1"
  "docker.elastic.co/kibana/kibana:8.17.1"
  "docker.elastic.co/apm/apm-server:8.17.1"
  "docker.elastic.co/beats/elastic-agent:8.17.1"
  "docker.io/busybox:1.37.0"
  "docker.io/grafana/grafana:11.5.1"
  "docker.io/library/busybox:1.37.0"
  "docker.io/traefik:v2.11.2"
  "ghcr.io/fluxcd/flagger:1.40.0"
  "ghcr.io/fluxcd/flagger-loadtester:0.34.0"
  "ghcr.io/kedacore/keda:2.16.1"
  "ghcr.io/kedacore/keda-metrics-apiserver:2.16.1"
  "ghcr.io/kedacore/keda-admission-webhooks:2.16.1"
  "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.120.0"
  "joxit/docker-registry-ui:2.5.7"
  "openpolicyagent/gatekeeper:v3.18.2"
  "openpolicyagent/gatekeeper-crds:v3.18.2"
  "prometheuscommunity/bind-exporter:v0.8.0"
  "quay.io/jetstack/cert-manager-acmesolver:v1.17.1"
  "quay.io/jetstack/cert-manager-cainjector:v1.17.1"
  "quay.io/jetstack/cert-manager-controller:v1.17.1"
  "quay.io/jetstack/cert-manager-startupapicheck:v1.17.1"
  "quay.io/jetstack/cert-manager-webhook:v1.17.1"
  "quay.io/kiwigrid/k8s-sidecar:1.28.0"
  "quay.io/prometheus/alertmanager:v0.28.0"
  "quay.io/prometheus/node-exporter:v1.9.0"
  "quay.io/prometheus/prometheus:v3.1.0"
  "quay.io/prometheus-operator/admission-webhook:v0.80.0"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.80.0"
  "quay.io/prometheus-operator/prometheus-operator:v0.80.0"
  "registry.k8s.io/external-dns/external-dns:v0.15.1"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.1"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0"
  "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
  "ubuntu/bind9:9.18-22.04_beta"
)

mkdir -p "./logs/trivy/container-images"

for source_image in "${IMAGES[@]}"; do
  target_image="$LOCAL_REGISTRY/$source_image"
  if ! curl -s -f -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.oci.image.manifest.v2+json" "https://$LOCAL_REGISTRY/v2/${source_image%:*}/manifests/${source_image#*:}" >/dev/null 2>&1; then
    echo "Importing Image to Local Registry: $source_image"

    docker pull "$source_image"
    image_name_safe=$(echo "$source_image" | sed 's/[\/:]/_/g')
    docker run --rm \
      -v "/var/run/docker.sock:/var/run/docker.sock" \
      -v "$HOME/Library/Caches:/root/.cache/" \
      -v "$(pwd)/logs/trivy/container-images:/logs" \
      ghcr.io/aquasecurity/trivy:0.59.0 \
      image "$source_image" > "./logs/trivy/container-images/${image_name_safe}.log"
    docker tag "$source_image" "$target_image"
    docker push "$target_image"
  fi
done

# Cluster
mkdir -p "./temp"

envsubst < "./configs/cluster/kind-config.yaml" > "./temp/kind-config.yaml"

if ! kind get clusters | grep -q "^local-dev$"; then
  kind create cluster --name local-dev --config "./temp/kind-config.yaml"
  for node in $(kind get nodes --name local-dev); do
    docker exec "$node" bash -c "
      update-ca-certificates
    "
  done
else
  echo "Cluster Already Created..."
fi

# Install Grafana dashboards
helm upgrade grafana-dashboards ./charts/grafana-dashboards \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

# Prometheus Stack
if [ ! -f "./temp/secrets/grafana.key" ]; then
  (LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24) > "./temp/secrets/grafana.key"
fi

GRAFANA_PASSWORD=$(cat "./temp/secrets/grafana.key")

helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --values "./values/prometheus-values.yaml" \
  --set "grafana.adminPassword=$GRAFANA_PASSWORD" \
  --version 69.4.1 \
  --wait

# Metrics Server
helm upgrade metrics-server metrics-server/metrics-server \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --values "./values/metrics-server-values.yaml" \
  --version 3.12.2 \
  --wait

# Gatekeeper
helm upgrade gatekeeper gatekeeper/gatekeeper \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace gatekeeper-system \
  --values "./values/gatekeeper-values.yaml" \
  --version 3.18.2 \
  --wait

# Cert Manager
helm upgrade cert-manager jetstack/cert-manager \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace cert-manager \
  --values "./values/cert-manager-values.yaml" \
  --version v1.17.1 \
  --wait

helm upgrade cluster-issuer ./charts/cluster-issuer \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace cert-manager \
  --set "ca.crt=$(base64 -i "./temp/secrets/ca.crt")" \
  --set "ca.key=$(base64 -i "./temp/secrets/ca.key")" \
  --wait

# DNS
helm upgrade bind9 ./charts/bind9 \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace dns \
  --set "tsigKey=$TSIG_KEY" \
  --wait

# Elastic Stack
helm upgrade elastic-operator elastic/eck-operator \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace elastic-system \
  --values "./values/elastic-operator-values.yaml" \
  --version 2.16.1 \
  --wait

helm upgrade elasticsearch ./charts/elasticsearch \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

kubectl wait --for=condition=reconciliationcomplete elasticsearch/elasticsearch -n monitoring --timeout=300s

helm upgrade kibana ./charts/kibana \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green kibana/kibana -n monitoring --timeout=300s

helm upgrade apm-server ./charts/apm-server \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green apmserver/apm-server -n monitoring --timeout=300s

helm upgrade fleet-server ./charts/fleet-server \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green agent/fleet-server -n monitoring --timeout=300s

helm upgrade elastic-agent ./charts/elastic-agent \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green agent/elastic-agent -n monitoring --timeout=300s

# OpenTelemetry Collector
ELASTIC_APM_SECRET_TOKEN=$(kubectl get secret apm-server-apm-token -n monitoring -o=jsonpath='{.data.secret-token}' | base64 --decode)

helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace monitoring \
  --values "./values/otel-collector-values.yaml" \
  --set config.exporters.otlp.headers.Authorization="Bearer ${ELASTIC_APM_SECRET_TOKEN}" \
  --version 0.117.0 \
  --wait

# Traefik
helm upgrade certificates ./charts/certificates \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace traefik \
  --wait

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --version 22.3.0 \
  --wait

# External DNS
helm upgrade external-dns ./charts/external-dns \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace dns \
  --set "tsigKey=$TSIG_KEY" \
  --wait

# Container Registry UI
helm upgrade registry-ui joxit/docker-registry-ui \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace registry \
  --values "./values/registry-ui-values.yaml" \
  --version 1.1.3 \
  --wait

## Flagger
helm upgrade flagger flagger/flagger \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace flagger \
  --values "./values/flagger-values.yaml" \
  --version 1.40.0 \
  --wait

helm upgrade flagger-loadtester flagger/loadtester \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace flagger \
  --values "./values/flagger-loadtester-values.yaml" \
  --version 0.34.0 \
  --wait

# KEDA
helm upgrade keda keda/keda \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace keda \
  --values "./values/keda-values.yaml" \
  --version 2.16.1 \
  --wait

## Update DNS Server
for service in $(networksetup -listallnetworkservices | tail -n +2); do
  if networksetup -getinfo "$service" | grep "IP address" | grep -qv "none"; then
    active_service="$service"
    break
  fi
done

echo "Updating DNS Server for Network $active_service to 127.0.0.1..."
sudo networksetup -setdnsservers "$active_service" "127.0.0.1"

# Flush DNS Cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "DNS cache flushed successfully"

# Dashboard
if [ ! -f "./temp/dashboard_version" ]; then
  echo "0" > "./temp/dashboard_version"
fi

DASHBOARD_VERSION=$(($(cat "./temp/dashboard_version") + 1))
echo "$DASHBOARD_VERSION" > "./temp/dashboard_version"

docker build -t "registry.local.dev:5001/dashboard:v${DASHBOARD_VERSION}" ./src/dashboard -f ./src/dashboard/server.Dockerfile
docker build -t "registry.local.dev:5001/dashboard-tests:v${DASHBOARD_VERSION}" ./src/dashboard -f ./src/dashboard/tests.Dockerfile

docker run --rm \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "$HOME/Library/Caches:/root/.cache/" \
  -v "$(pwd)/logs/trivy/container-images:/logs" \
  ghcr.io/aquasecurity/trivy:0.59.0 \
  image "registry.local.dev:5001/dashboard:v${DASHBOARD_VERSION}" > "./logs/trivy/container-images/registry.local.dev_5001_dashboard_v${DASHBOARD_VERSION}.log"

docker run --rm \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "$HOME/Library/Caches:/root/.cache/" \
  -v "$(pwd)/logs/trivy/container-images:/logs" \
  ghcr.io/aquasecurity/trivy:0.59.0 \
  image "registry.local.dev:5001/dashboard-tests:v${DASHBOARD_VERSION}" > "./logs/trivy/registry.local.dev_5001_dashboard-tests_v${DASHBOARD_VERSION}.log"

docker push "registry.local.dev:5001/dashboard:v${DASHBOARD_VERSION}"
docker push "registry.local.dev:5001/dashboard-tests:v${DASHBOARD_VERSION}"

helm upgrade dashboard ./charts/dashboard \
  --create-namespace \
  --hide-notes \
  --install \
  --namespace dashboard \
  --set "imageTag=v${DASHBOARD_VERSION}" \
  --wait

echo "Dashboard is running on https://dashboard.local.dev"

echo "Generating traffic to the dashboard for canary analysis..."
hey -z 2m -q 100 -c 1 https://dashboard.local.dev
