#!/bin/bash

set -e

# Function to get the active network service
get_active_service() {
  local services=$(networksetup -listallnetworkservices | tail -n +2)
  for service in $services; do
    # Check if the service is active by attempting to get its IP address
    if [[ $(networksetup -getinfo "$service" | grep "IP address" | grep -v "none") ]]; then
      echo "$service"
      return 0
    fi
  done
  return 1
}

networksetup -setdnsservers "$(get_active_service)" "empty"

kind delete cluster

if docker ps -f name=registry | grep -q registry; then
  docker rm -f registry
fi

if security find-certificate -c "Local Dev Root" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  sudo security delete-certificate -c "Local Dev Root" /Library/Keychains/System.keychain
fi
