#!/bin/bash
set -e

# Build the Docker image
docker build -t registry.local.dev:5001/weather-api:latest .

# Push to local registry
docker push registry.local.dev:5001/weather-api:latest

# Deploy using Helm
helm upgrade weather-api ./helm \
  --create-namespace \
  --install \
  --namespace weather-api \
  --wait
