#!/bin/bash

docker run -d --restart=always -p 5000:5000 --name registry --network kind registry:2

kind create cluster --config kind-config.yaml
