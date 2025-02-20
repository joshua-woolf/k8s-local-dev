#!/bin/bash

# Exit on error
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

# Function to get current DNS servers
get_dns_servers() {
  local service="$1"
  networksetup -getdnsservers "$service"
}

# Function to set DNS servers
set_dns_servers() {
  local service="$1"
  shift
  local servers=("$@")

  # Convert array to space-separated string
  local server_string="${servers[*]}"

  echo "Setting DNS servers for $service to: $server_string"
  networksetup -setdnsservers "$service" "${servers[@]}"
}

# Main script
main() {
  # Get active network service
  local active_service=$(get_active_service)
  if [[ -z "$active_service" ]]; then
    echo "Error: No active network service found"
    exit 1
  fi
  echo "Active network service: $active_service"

  # Get current DNS servers
  local current_servers=($(get_dns_servers "$active_service"))

  # Check if there are any DNS servers configured
  if [[ "${current_servers[*]}" == "There aren't any DNS Servers set on"* ]] || [[ "${current_servers[*]}" == "Empty"* ]]; then
    echo "No DNS servers currently configured. Setting 127.0.0.1 as primary DNS server."
    set_dns_servers "$active_service" "127.0.0.1"

    # Flush DNS Cache
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    echo "DNS cache flushed successfully"

    exit 0
  fi

  # Check if 127.0.0.1 is already the first server
  if [[ "${current_servers[0]}" == "127.0.0.1" ]]; then
    echo "127.0.0.1 is already the first DNS server. No changes needed."

    # Flush DNS Cache
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    echo "DNS cache flushed successfully"

    exit 0
  fi

  # Create new array with 127.0.0.1 as first server
  local new_servers=("127.0.0.1")
  for server in "${current_servers[@]}"; do
    if [[ "$server" != "127.0.0.1" ]]; then
      new_servers+=("$server")
    fi
  done

  # Set the new DNS servers
  set_dns_servers "$active_service" "${new_servers[@]}"
  echo "DNS servers updated successfully"

  # Flush DNS Cache
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
  echo "DNS cache flushed successfully"
}

# Run main function with sudo privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo privileges"
  exec sudo "$0" "$@"
else
  main "$@"
fi
