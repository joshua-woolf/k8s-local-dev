#!/bin/bash

docker run -d --restart=always -p 5000:5000 --name registry --network kind registry:2

echo "Container Registry is running on http://localhost:5000"

kind create cluster --config kind-config.yaml

# Bind9

docker build -t localhost:5000/bind9:latest ./dns/
docker push localhost:5000/bind9:latest

kubectl apply -f ./dns/dns.yaml

# Helm Repos

helm repo add elastic https://helm.elastic.co
helm repo add flagger https://flagger.app
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts
helm repo add jetstack https://charts.jetstack.io

helm repo update elastic flagger metrics-server open-telemetry podinfo prometheus-community traefik jetstack

# Generate CA and trust it
chmod +x ./certs/generate-ca.sh
./certs/generate-ca.sh

# Install cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  --create-namespace \
  --install \
  --namespace cert-manager \
  --values "./certs/cert-manager.yaml" \
  --wait

# Configure cert-manager with our CA
kubectl apply -f ./certs/ca/cluster-issuer.yaml

# Metrics Server

helm upgrade metrics-server metrics-server/metrics-server \
  --create-namespace \
  --install \
  --namespace monitoring \
  --values "./values/metrics-server-values.yaml" \
  --wait

# ExternalDNS

kubectl apply -f ./dns/external-dns.yaml

# Traefik

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --wait

echo "Traefik Dashboard is running on http://traefik.local.dev"

# PodInfo

helm upgrade podinfo podinfo/podinfo \
  --create-namespace \
  --install \
  --namespace podinfo \
  --values "./values/podinfo-values.yaml" \
  --wait

echo "PodInfo is running on http://podinfo.local.dev"

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

# sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
