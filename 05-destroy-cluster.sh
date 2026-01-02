#!/bin/bash
set -euo pipefail

# Define colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

echo -e "${BLUE}>>> Destroying Kubernetes cluster VMs...${NC}"

VMS=("master01" "master02" "worker01" "worker02")
PROJECT_DIR="$(pwd)"
SHARE_DIR="${PROJECT_DIR}/_cluster_share"

# Delete VMs sequentially to avoid crashing multipassd
for vm in "${VMS[@]}"; do
    if multipass info "$vm" >/dev/null 2>&1; then
        echo -e "${YELLOW}>>> Deleting ${vm}...${NC}"
        multipass delete "$vm" >/dev/null 2>&1
        echo -e "${GREEN}>>> ${vm} deleted.${NC}"
    else
        echo -e "${BLUE}>>> VM ${vm} does not exist, skipping.${NC}"
    fi
done

echo -e "${GREEN}>>> All delete commands finished.${NC}"

echo -e "${BLUE}>>> Purging deleted VMs...${NC}"
multipass purge
echo -e "${GREEN}>>> Purge complete.${NC}"

# Clean up shared directory
if [ -d "$SHARE_DIR" ]; then
    echo -e "${BLUE}>>> Removing shared directory ${SHARE_DIR}...${NC}"
    rm -rf "$SHARE_DIR"
fi

# Clean up hosts file entries on the HOST machine (if possible/needed, but user has separate script for that)
# We will just stick to the original logic of clearing dhcpd_leases which seems specific to this user's environment.
echo -e "${YELLOW}>>> Clearing /var/db/dhcpd_leases for a clean state...${NC}"
if [ -f /var/db/dhcpd_leases ]; then
    sudo sh -c ': > /var/db/dhcpd_leases'
    echo -e "${GREEN}>>> DHCP leases cleared.${NC}"
else
    echo -e "${BLUE}>>> /var/db/dhcpd_leases not found, skipping.${NC}"
fi

echo -e "${GREEN}>>> Cluster VMs destroyed and resources released.${NC}"
