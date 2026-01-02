#!/bin/bash
set -euo pipefail

# This script must be run with sudo, as it modifies /etc/hosts.
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo ./05-host-setup/update-hosts-file.sh"
  exit 1
fi

if [ -z "$SUDO_USER" ]; then
    echo "ERROR: This script should be run with 'sudo' from a regular user session, not directly as root."
    exit 1
fi

echo ">>> Updating host's /etc/hosts file with Multipass VM IPs..."

HOSTS_FILE="/etc/hosts"
START_MARKER="# BEGIN: K8S_LAB_ENTRIES"
END_MARKER="# END: K8S_LAB_ENTRIES"

# First, remove any existing block to ensure idempotency
if grep -q "$START_MARKER" "$HOSTS_FILE"; then
    echo ">>> Found existing k8s-lab entries. Removing before update..."
    # Use sed to delete the block between the markers
    sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$HOSTS_FILE"
    rm -f "${HOSTS_FILE}.bak"
fi

# Generate the new entries
echo ">>> Generating new host entries..."
HOST_ENTRIES=""
for vm in master01 master02 worker01 worker02; do
    # IMPORTANT: Run multipass commands as the original user who invoked sudo
    if sudo -u "$SUDO_USER" multipass info "$vm" >/dev/null 2>&1; then
        ip=$(sudo -u "$SUDO_USER" multipass info "$vm" --format json | jq -r ".info.${vm}.ipv4[0]")
        HOST_ENTRIES="${HOST_ENTRIES}${ip} ${vm}\n"
    else
        echo "WARNING: VM ${vm} not found, cannot add it to /etc/hosts."
    fi
done

# Add the new block to /etc/hosts
if [ -n "$HOST_ENTRIES" ]; then
    echo ">>> Appending new entries to $HOSTS_FILE"
    {
        echo "$START_MARKER"
        echo -e "$HOST_ENTRIES"
        echo "$END_MARKER"
    } >> "$HOSTS_FILE"
    echo ">>> Successfully updated /etc/hosts."
else
    echo ">>> No running VMs found to add to /etc/hosts."
fi
