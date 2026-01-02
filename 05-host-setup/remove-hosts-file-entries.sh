#!/bin/bash
set -euo pipefail

# This script must be run with sudo, as it modifies /etc/hosts.
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo ./05-host-setup/remove-hosts-file-entries.sh"
  exit 1
fi

echo ">>> Removing k8s-lab VM entries from host's /etc/hosts file..."

HOSTS_FILE="/etc/hosts"
START_MARKER="# BEGIN: K8S_LAB_ENTRIES"
END_MARKER="# END: K8S_LAB_ENTRIES"

if grep -q "$START_MARKER" "$HOSTS_FILE"; then
    echo ">>> Found k8s-lab entries. Removing now..."
    # Use sed to delete the block between the markers
    sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$HOSTS_FILE"
    rm -f "${HOSTS_FILE}.bak"
    echo ">>> Entries successfully removed from /etc/hosts."
else
    echo ">>> No k8s-lab entries found in /etc/hosts. Nothing to do."
fi
