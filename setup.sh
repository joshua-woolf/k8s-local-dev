#!/bin/bash

# Helm Repos
helm repo add elastic https://helm.elastic.co
helm repo add flagger https://flagger.app
helm repo add jetstack https://charts.jetstack.io
helm repo add joxit https://helm.joxit.dev
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts

helm repo update elastic flagger jetstack joxit metrics-server open-telemetry podinfo prometheus-community traefik

# Trusted Root CA Certificate
if ! security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  echo "Installing Root CA to System Keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "./certs/ca.crt"
fi

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

# Metrics Server
helm upgrade metrics-server metrics-server/metrics-server \
  --create-namespace \
  --install \
  --namespace monitoring \
  --values "./values/metrics-server-values.yaml" \
  --wait

# Cert Manager
helm upgrade cert-manager jetstack/cert-manager \
  --create-namespace \
  --install \
  --namespace cert-manager \
  --values "./values/cert-manager-values.yaml" \
  --wait

kubectl apply -f ./certs/cluster-issuer.yaml

# DNS
kubectl apply -f ./dns/dns.yaml
kubectl apply -f ./dns/external-dns.yaml

# Container Registry
kubectl apply -f ./registry/certificate.yaml

echo "Waiting for Registry TLS certificate to be created..."
max_attempts=30
attempt=1
while ! kubectl get secret -n registry registry-tls >/dev/null 2>&1; do
  if [ $attempt -ge $max_attempts ]; then
    echo "Timeout waiting for registry secret"
    exit 1
  fi
  echo "Attempt $attempt/$max_attempts: Secret not found, waiting..."
  sleep 10
  ((attempt++))
done

echo "Extracting Registry TLS certificate and key..."
mkdir -p ./certs/registry
kubectl get secret -n registry registry-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > ./certs/registry/registry.crt
kubectl get secret -n registry registry-tls -o jsonpath='{.data.tls\.key}' | base64 -d > ./certs/registry/registry.key

docker run -d --restart=always \
  -v ./certs/registry:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin='["https://registry.local.dev"]' \
  -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods='["DELETE", "GET", "HEAD", "OPTIONS"]' \
  -e REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers='["Authorization", "Accept", "Cache-Control"]' \
  -e REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers='["Docker-Content-Digest"]' \
  -p 5001:443 --name registry --network kind registry:2

echo "Registry is running on https://registry.local.dev:5001"

helm upgrade registry-ui joxit/docker-registry-ui \
  --create-namespace \
  --install \
  --namespace registry \
  --values "./values/registry-ui-values.yaml" \
  --wait

echo "Registry UI is running on https://registry.local.dev"

# Traefik
kubectl apply -f ./traefik/certificate.yaml

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --wait

echo "Traefik Dashboard is running on http://traefik.local.dev"

# Prometheus Stack
helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --install \
  --namespace monitoring \
  --values "./values/prometheus-values.yaml" \
  --wait

echo "Grafana is running on http://grafana.local.dev"

echo -n "Username: "
kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 --decode ; echo
echo -n "Password: "
kubectl get secret --namespace monitoring kube-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

echo "Prometheus is running on http://prometheus.local.dev"

# OpenTelemetry Collector
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  --create-namespace \
  --install \
  --namespace monitoring \
  --values "./values/otel-collector-values.yaml" \
  --wait

## Flagger
helm upgrade flagger flagger/flagger \
  --create-namespace \
  --install \
  --namespace flagger \
  --values "./values/flagger-values.yaml" \
  --wait

helm upgrade flagger-loadtester flagger/loadtester \
  --create-namespace \
  --install \
  --namespace flagger \
  --values "./values/flagger-loadtester-values.yaml" \
  --wait

# Elastic Stack
helm upgrade elastic-operator elastic/eck-operator \
  --create-namespace \
  --install \
  --namespace elastic-system \
  --values "./values/elastic-operator-values.yaml" \
  --wait

kubectl apply -f ./elastic/elastic.yaml

# PodInfo
helm upgrade podinfo podinfo/podinfo \
  --create-namespace \
  --install \
  --namespace podinfo \
  --values "./values/podinfo-values.yaml" \
  --wait

echo "PodInfo is running on http://podinfo.local.dev"

# Weather API
cd weather-api && ./deploy.sh && cd ..

echo "Weather API is running on https://weather.local.dev"
