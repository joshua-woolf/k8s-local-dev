#!/bin/bash

docker run -d --restart=always -p 5000:5000 --name registry --network kind registry:2

kind create cluster --config kind-config.yaml

## Bind9

docker build -t localhost:5000/bind9:latest ./dns/
docker push localhost:5000/bind9:latest

kubectl apply -f ./dns/dns.yaml

## Helm Repos

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo add traefik https://traefik.github.io/charts

helm repo update

## Traefik

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --wait

## Podinfo

helm upgrade podinfo podinfo/podinfo \
  --create-namespace \
  --install \
  --namespace demo \
  --values "./values/podinfo-values.yaml" \
  --wait
