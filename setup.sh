#!/bin/bash

# Helm Repos
helm repo add elastic https://helm.elastic.co
helm repo add flagger https://flagger.app
helm repo add jetstack https://charts.jetstack.io
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts
helm repo add twuni https://helm.twun.io

helm repo update elastic flagger jetstack metrics-server open-telemetry podinfo prometheus-community traefik twuni

# Trusted Root CA Certificate
if ! security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  echo "Installing Root CA to System Keychain..."
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "./certs/ca/ca.crt"
fi

# Cluster
kind create cluster --config kind-config.yaml

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

kubectl apply -f ./certs/ca/cluster-issuer.yaml

# DNS
kubectl apply -f ./dns/dns.yaml
kubectl apply -f ./dns/external-dns.yaml

# Container Registry
helm upgrade registry twuni/docker-registry \
  --create-namespace \
  --install \
  --namespace registry \
  --values "./values/registry-values.yaml" \
  --wait

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

# sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
