#!/bin/bash

set -e

# Reset Dashboard Version
rm -f "./temp/dashboard_version"

# Reset DNS Servers
services=$(networksetup -listallnetworkservices | tail -n +2)

for service in $services; do
  if [[ $(networksetup -getinfo "$service" | grep "IP address" | grep -v "none") ]]; then
    networksetup -setdnsservers "$service" "empty"
    break
  fi
done

# Delete Cluster
kind delete cluster --name local-dev

# Delete Registry
if docker ps -f name=registry | grep -q registry; then
  docker rm -f registry
fi

# Delete Root CA
if security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  sudo security delete-certificate -c "Local Dev Root" /Library/Keychains/System.keychain
fi
