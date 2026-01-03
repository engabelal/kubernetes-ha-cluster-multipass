#!/bin/bash
# =============================================================================
# Restore Kubernetes Cluster
# Purpose: Restore all cluster VMs to a specific snapshot state
# =============================================================================

set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# List of VMs to restore
VMS=("haproxy" "master01" "master02" "worker01" "worker02")

echo -e "${RED}>>> DANGER: Restore Kubernetes Cluster Tool${NC}"
echo -e "This will STOP the cluster and revert all VMs to a previous state."
echo -e "Current data since that snapshot will be ${RED}LOST${NC}."
echo ""

# Show available snapshots
echo -e "${YELLOW}>>> Available Snapshots:${NC}"
multipass list --snapshots | grep "master01" | awk '{print $2}' || echo "No snapshots found found for master01."
echo ""

# Ask for snapshot name to restore
read -p "Enter the snapshot name to restore (e.g., 'fresh-install'): " SNAP_NAME

if [[ -z "$SNAP_NAME" ]]; then
    echo -e "${RED}Error: Snapshot name cannot be empty.${NC}"
    exit 1
fi

echo ""
read -p "Are you sure you want to restore snapshot '${SNAP_NAME}' on ALL nodes? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}>>> Stopping cluster first...${NC}"
./04-stop-cluster.sh

echo ""
echo -e "${YELLOW}>>> Restoring snapshot '${SNAP_NAME}'...${NC}"

for vm in "${VMS[@]}"; do
    if multipass list | grep -q "$vm"; then
        echo -e "  > Restoring ${GREEN}$vm${NC} to '$SNAP_NAME'..."

        # Check if snapshot exists for this VM using list --snapshots
        if multipass list --snapshots | grep "$vm" | grep -q "$SNAP_NAME"; then
             multipass restore "$vm.$SNAP_NAME"
             echo -e "    ${GREEN}Restored.${NC}"
        else
             echo -e "    ${RED}Snapshot '$SNAP_NAME' not found for $vm. Skipping.${NC}"
        fi
    else
        echo -e "  > ${RED}$vm not found, skipping.${NC}"
    fi
done

echo ""
echo -e "${GREEN}>>> Restore completed!${NC}"
echo -e "${YELLOW}>>> You can now start the cluster using ./03-start-cluster.sh${NC}"
