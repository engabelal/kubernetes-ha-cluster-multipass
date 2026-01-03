#!/bin/bash
# =============================================================================
# Fix Cluster DNS / Hosts File
# Purpose: Re-populate /etc/hosts on all nodes with current IPs.
#          Fixes 'NotReady' status caused by DNS failures after Restore/Reboot.
# =============================================================================

set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

VMS=("haproxy" "master01" "master02" "worker01" "worker02")

echo -e "${YELLOW}>>> Fixing Cluster DNS (Updating /etc/hosts on all nodes)...${NC}"

# 1. Gather IPs and Build Host Block
echo -e "Gathering current IPs..."
HOSTS_BLOCK=""

for vm in "${VMS[@]}"; do
    if multipass list | grep -q "$vm"; then
        IP=$(multipass info "$vm" --format json | jq -r ".info.\"$vm\".ipv4[0]")
        if [[ ! -z "$IP" ]]; then
            echo -e "  > $vm: ${GREEN}$IP${NC}"
            HOSTS_BLOCK+="$IP $vm\n"
        fi
    else
        echo -e "  > ${RED}$vm not found!${NC}"
    fi
done

# 3. Update /etc/hosts on each VM
echo ""
echo -e "${YELLOW}>>> Applying updates to VMs...${NC}"

for vm in "${VMS[@]}"; do
    echo -e "  > Updating ${BLUE}$vm${NC}..."

    # Remove old entries for cluster nodes to avoid duplicates
    # We construct a grep pattern to remove lines containing any of the VM names
    for target in "${VMS[@]}"; do
        multipass exec "$vm" -- sudo sed -i "/$target/d" /etc/hosts
    done

    # Append new block
    # We echo the block and tee -a to append
    multipass exec "$vm" -- bash -c "echo -e \"$HOSTS_BLOCK\" | sudo tee -a /etc/hosts > /dev/null"

    echo -e "    ${GREEN}Done.${NC}"
done

echo ""
echo -e "${GREEN}>>> DNS Fix Completed!${NC}"
echo -e "Cluster nodes should recover automatically in 1-2 minutes."
