#!/bin/bash

docker run -d --restart=always -p 5000:5000 --name registry --network kind registry:2

echo "Container Registry is running on http://localhost:5000"

kind create cluster --config kind-config.yaml

## Bind9

docker build -t localhost:5000/bind9:latest ./dns/
docker push localhost:5000/bind9:latest

kubectl apply -f ./dns/dns.yaml

## Helm Repos

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts

helm repo update

## Traefik

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --wait

echo "Traefik Dashboard is running on http://traefik.local.dev"

## PodInfo

helm upgrade podinfo podinfo/podinfo \
  --create-namespace \
  --install \
  --namespace podinfo \
  --values "./values/podinfo-values.yaml" \
  --wait

echo "PodInfo is running on http://podinfo.local.dev"

## Prometheus Stack

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
