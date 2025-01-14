#!/bin/bash

docker run -d --restart=always -p 5000:5000 --name registry --network kind registry:2

kind create cluster --config kind-config.yaml

## Traefik

helm repo add traefik https://traefik.github.io/charts
helm repo update

helm upgrade traefik traefik/traefik \
  --create-namespace \
  --install \
  --namespace traefik \
  --values "./values/traefik-values.yaml" \
  --wait
