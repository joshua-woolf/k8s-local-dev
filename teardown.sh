#!/bin/bash

kind delete cluster

if docker ps -f name=registry | grep -q registry; then
  docker rm -f registry
fi

if security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  sudo security delete-certificate -c "Local Dev Root" /Library/Keychains/System.keychain
fi
