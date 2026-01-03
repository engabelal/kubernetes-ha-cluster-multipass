#!/bin/bash
# =============================================================================
# Snapshot Kubernetes Cluster
# Purpose: Take a snapshot of the current state of all cluster VMs
# =============================================================================

set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# List of VMs to snapshot
VMS=("haproxy" "master01" "master02" "worker01" "worker02")

echo -e "${YELLOW}>>> Kubernetes Cluster Snapshot Tool${NC}"
echo -e "This will take a snapshot of: ${GREEN}${VMS[*]}${NC}"
echo ""

# Ask for snapshot name
read -p "Enter a name for this snapshot (e.g., 'fresh-install', 'before-upgrade'): " SNAP_NAME

if [[ -z "$SNAP_NAME" ]]; then
    echo -e "${RED}Error: Snapshot name cannot be empty.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}>>> Stopping cluster VMs before snapshot (Required)...${NC}"
./04-stop-cluster.sh

echo ""
echo -e "${YELLOW}>>> Creating snapshot '${SNAP_NAME}' for all nodes...${NC}"

for vm in "${VMS[@]}"; do
    # Check if VM exists
    if multipass list | grep -q "$vm"; then
        echo -e "  > Snapshotting ${GREEN}$vm${NC}..."
        # We try to create a snapshot.
        if multipass snapshot "$vm" --name "$SNAP_NAME"; then
             echo -e "    ${GREEN}Success.${NC}"
        else
             echo -e "    ${RED}Failed.${NC}"
        fi
    else
        echo -e "  > ${RED}$vm not found, skipping.${NC}"
    fi
done

echo ""
echo -e "${GREEN}>>> Snapshot process completed!${NC}"
echo -e "You can see snapshots using: ${YELLOW}multipass info <vm-name>${NC}"

echo ""
read -p "Do you want to start the cluster again now? (y/N): " START_CONFIRM
if [[ "$START_CONFIRM" == "y" || "$START_CONFIRM" == "Y" ]]; then
    ./03-start-cluster.sh
fi
