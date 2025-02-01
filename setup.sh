#!/bin/bash

# Helm Repos
helm repo add elastic https://helm.elastic.co
helm repo add flagger https://flagger.app
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add joxit https://helm.joxit.dev
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts

helm repo update elastic flagger gatekeeper jetstack joxit metrics-server open-telemetry podinfo prometheus-community traefik

# Trusted Root CA Certificate
if ! security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  echo "Installing Root CA to System Keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "./certs/ca.crt"
fi

# Create Registry Certificate Private Key
openssl genrsa -out "certs/registry.key" 2048

# Create Registry Certificate Signing Request
openssl req -new \
  -key "certs/registry.key" \
  -config "certs/registry.conf" \
  -out "certs/registry.csr"

# Sign the Registry Certificate with the Certificate Authority
openssl x509 -req \
  -in "certs/registry.csr" \
  -CA "certs/ca.crt" \
  -CAkey "certs/ca.key" \
  -CAcreateserial \
  -out "certs/registry.crt" \
  -days 365 \
  -sha256 \
  -extfile "certs/registry-signing.conf" \
  -extensions v3_ext

# Container Registry
if docker ps -f name=registry | grep -q registry; then
  echo "Registry container already running"
else
  docker run -d --restart=always \
    -v ./certs:/certs \
    -v ./registry/data:/var/lib/registry \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers='["Authorization", "Accept", "Cache-Control"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods='["DELETE", "GET", "HEAD", "OPTIONS"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin='["https://registry.local.dev"]' \
    -e REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers='["Docker-Content-Digest"]' \
    -e REGISTRY_HTTP_SECRET=345704b227b4dac03f0c06ddaecc7ab7349f7f0e33b8cc4cb4e73c4936c50d81 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
    -e REGISTRY_LOG_FORMATTER=json \
    -e REGISTRY_LOG_LEVEL=info \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true \
    -p 5001:443 --name registry --network kind registry:2.8.3@sha256:319881be2ee9e345d5837d15842a04268de6a139e23be42654fc7664fc6eaf52
fi

echo "Registry is running on https://registry.local.dev:5001"

# Image Caching
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
  "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.118.0"
  "ghcr.io/stefanprodan/podinfo:6.7.1"
  "joxit/docker-registry-ui:2.5.2"
  "openpolicyagent/gatekeeper:v3.18.2"
  "openpolicyagent/gatekeeper-crds:v3.18.2"
  "prometheuscommunity/bind-exporter:v0.6.0"
  "quay.io/jetstack/cert-manager-acmesolver:v1.16.3"
  "quay.io/jetstack/cert-manager-cainjector:v1.16.3"
  "quay.io/jetstack/cert-manager-controller:v1.16.3"
  "quay.io/jetstack/cert-manager-startupapicheck:v1.16.3"
  "quay.io/jetstack/cert-manager-webhook:v1.16.3"
  "quay.io/kiwigrid/k8s-sidecar:1.28.0"
  "quay.io/prometheus/alertmanager:v0.28.0"
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
    docker run --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v "$HOME/Library/Caches:/root/.cache/" ghcr.io/aquasecurity/trivy:0.59.0 image "$source_image"
    docker tag "$source_image" "$target_image"
    docker push "$target_image"
  fi
done

# Cluster
if ! kind get clusters | grep -q "^kind$"; then
  kind create cluster --config kind-config.yaml
else
  echo "Cluster 'kind' already exists, skipping creation"
fi

for node in $(kind get nodes); do
  docker exec "$node" bash -c "
    update-ca-certificates
  "
done

# Prometheus Stack

# Install Grafana dashboards
helm upgrade grafana-dashboards ./charts/grafana-dashboards \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --values "./values/prometheus-values.yaml" \
  --version 68.3.0 \
  --wait

echo "Grafana is running on https://grafana.local.dev"

echo "Username: $(kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 --decode)"
echo "Password: $(kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"

echo "Prometheus is running on https://prometheus.local.dev"

# Metrics Server
helm upgrade metrics-server metrics-server/metrics-server \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --values "./values/metrics-server-values.yaml" \
  --version 3.12.2 \
  --wait

# Gatekeeper
helm upgrade gatekeeper gatekeeper/gatekeeper \
  --create-namespace \
  --install \
  --namespace gatekeeper-system \
  --values "./values/gatekeeper-values.yaml" \
  --version 3.18.2 \
  --wait

# Cert Manager
helm upgrade cert-manager jetstack/cert-manager \
  --create-namespace \
  --install \
  --namespace cert-manager \
  --hide-notes \
  --values "./values/cert-manager-values.yaml" \
  --version v1.16.3 \
  --wait

helm upgrade cluster-issuer ./charts/cluster-issuer \
  --create-namespace \
  --install \
  --namespace cert-manager \
  --hide-notes \
  --wait

# DNS
helm upgrade bind9 ./charts/bind9 \
  --create-namespace \
  --install \
  --namespace dns \
  --hide-notes \
  --wait

helm upgrade external-dns ./charts/external-dns \
  --create-namespace \
  --install \
  --namespace dns \
  --hide-notes \
  --wait

# Elastic Stack
helm upgrade elastic-operator elastic/eck-operator \
  --create-namespace \
  --install \
  --namespace elastic-system \
  --hide-notes \
  --values "./values/elastic-operator-values.yaml" \
  --version 2.16.1 \
  --wait


helm upgrade elasticsearch ./charts/elasticsearch \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

kubectl wait --for=condition=reconciliationcomplete elasticsearch/elasticsearch -n monitoring --timeout=300s

echo "Elasticsearch is running on https://elasticsearch.local.dev"

echo "Username: elastic"
echo "Password: $(kubectl get secret elasticsearch-es-elastic-user -n monitoring -o=jsonpath='{.data.elastic}' | base64 --decode)"

helm upgrade kibana ./charts/kibana \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green kibana/kibana -n monitoring --timeout=300s

echo "Kibana is running on https://kibana.local.dev"

echo "Username: elastic"
echo "Password: $(kubectl get secret elasticsearch-es-elastic-user -n monitoring -o=jsonpath='{.data.elastic}' | base64 --decode)"

helm upgrade apm-server ./charts/apm-server \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green apmserver/apm-server -n monitoring --timeout=300s

helm upgrade fleet-server ./charts/fleet-server \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green agent/fleet-server -n monitoring --timeout=300s

helm upgrade elastic-agent ./charts/elastic-agent \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --wait

kubectl wait --for=jsonpath='{.status.health}'=green agent/elastic-agent -n monitoring --timeout=300s

# OpenTelemetry Collector
ELASTIC_APM_SECRET_TOKEN=$(kubectl get secret apm-server-apm-token -n monitoring -o=jsonpath='{.data.secret-token}' | base64 --decode)

helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  --create-namespace \
  --install \
  --namespace monitoring \
  --hide-notes \
  --values "./values/otel-collector-values.yaml" \
  --set config.exporters.otlp.headers.Authorization="Bearer ${ELASTIC_APM_SECRET_TOKEN}" \
  --version 0.111.2 \
  --wait

# Traefik
helm upgrade certificates ./charts/certificates \
  --create-namespace \
  --install \
  --namespace traefik \
  --hide-notes \
  --wait

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --hide-notes \
  --values "./values/traefik-values.yaml" \
  --version 34.1.0 \
  --wait

echo "Traefik Dashboard is running on https://traefik.local.dev"

# Container Registry UI
helm upgrade registry-ui joxit/docker-registry-ui \
  --create-namespace \
  --install \
  --namespace registry \
  --hide-notes \
  --values "./values/registry-ui-values.yaml" \
  --version 1.1.3 \
  --wait

echo "Registry UI is running on https://registry.local.dev"

## Flagger
helm upgrade flagger flagger/flagger \
  --create-namespace \
  --install \
  --namespace flagger \
  --hide-notes \
  --values "./values/flagger-values.yaml" \
  --version 1.40.0 \
  --wait

helm upgrade flagger-loadtester flagger/loadtester \
  --create-namespace \
  --install \
  --namespace flagger \
  --hide-notes \
  --values "./values/flagger-loadtester-values.yaml" \
  --version 0.34.0 \
  --wait

# PodInfo
helm upgrade podinfo podinfo/podinfo \
  --create-namespace \
  --install \
  --namespace podinfo \
  --hide-notes \
  --values "./values/podinfo-values.yaml" \
  --version 6.1.4 \
  --wait

echo "PodInfo is running on https://podinfo.local.dev"

# Flush DNS Cache
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Weather API
docker build -t registry.local.dev:5001/weather-api:latest ./weather-api
docker push registry.local.dev:5001/weather-api:latest

helm upgrade weather-api ./weather-api/helm \
  --create-namespace \
  --install \
  --namespace weather-api \
  --hide-notes \
  --wait

echo "Weather API is running on https://weather.local.dev"
