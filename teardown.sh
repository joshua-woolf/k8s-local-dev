#!/bin/bash

kind delete cluster

if docker ps -f name=registry | grep -q registry; then
  docker rm -f registry
fi
