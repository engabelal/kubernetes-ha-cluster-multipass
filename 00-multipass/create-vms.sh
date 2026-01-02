#!/bin/bash
set -euo pipefail

# Define colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
NC="\033[0m"

echo -e "${BLUE}>>> Starting Parallel VM Creation for Kubernetes Cluster...${NC}"

# VM specifications
VM_IMAGE="24.04"
MASTER_CPUS=2
MASTER_MEM="4G"
MASTER_DISK="20G"
WORKER_CPUS=2
WORKER_MEM="2G"
WORKER_DISK="20G"

# Directories
PROJECT_DIR="$(pwd)"
SHARE_DIR="${PROJECT_DIR}/_cluster_share"
CLOUD_INIT_FILE="${PROJECT_DIR}/00-multipass/cloud-init/base.yaml"
LOGS_DIR="${PROJECT_DIR}/.vm_creation_logs"

# Ensure cloud-init exists
if [ ! -f "$CLOUD_INIT_FILE" ]; then
    echo -e "${RED}ERROR: Cloud-init file not found at ${CLOUD_INIT_FILE}${NC}"
    exit 1
fi

# Cleanup function
cleanup() {
    rm -rf "$LOGS_DIR"
}
trap cleanup EXIT INT TERM

# Create/Reset directories
echo -e "${GREEN}>>> Creating/Resetting shared directory: ${SHARE_DIR}${NC}"
rm -rf "$SHARE_DIR"
mkdir -p "$SHARE_DIR"
mkdir -p "$LOGS_DIR"

# Function: launch_vm
# Purpose: Launches a multipass VM with the given name and Ubuntu version.
# Note: Checks if VM exists first to avoid errors. Captures logs to hidden directory.
launch_vm() {
    local name=$1
    local cpus=$2
    local mem=$3
    local disk=$4

    if multipass info "$name" >/dev/null 2>&1; then
        echo "Exists" > "${LOGS_DIR}/${name}.status"
        return 0
    else
        # Redirect output to log file to keep screen clean
        if multipass launch --name "$name" --cpus "$cpus" --memory "$mem" --disk "$disk" --cloud-init "$CLOUD_INIT_FILE" "$VM_IMAGE" > "${LOGS_DIR}/${name}.log" 2>&1; then
             # Verify it actually exists
             if multipass info "$name" >/dev/null 2>&1; then
                 echo "Success" > "${LOGS_DIR}/${name}.status"
                 return 0
             else
                 echo "Failed" > "${LOGS_DIR}/${name}.status"
                 echo "Error: multipass launch returned 0 but VM $name does not exist." >> "${LOGS_DIR}/creation_errors.log"
                 return 1
             fi
        else
             echo "Failed" > "${LOGS_DIR}/${name}.status"
             echo "Error creating $name" >> "${LOGS_DIR}/creation_errors.log"
             return 1
        fi
    fi
}

# Launch VMs in parallel (staggered)
echo -e "${BLUE}>>> Launching VMs... (Staggering starts to avoid overload)${NC}"

# Start background jobs with delays
launch_vm master01 "$MASTER_CPUS" "$MASTER_MEM" "$MASTER_DISK" &
PIDS[0]=$!
NAMES[0]="master01"
sleep 5

launch_vm master02 "$MASTER_CPUS" "$MASTER_MEM" "$MASTER_DISK" &
PIDS[1]=$!
NAMES[1]="master02"
sleep 5

launch_vm worker01 "$WORKER_CPUS" "$WORKER_MEM" "$WORKER_DISK" &
PIDS[2]=$!
NAMES[2]="worker01"
sleep 5

launch_vm worker02 "$WORKER_CPUS" "$WORKER_MEM" "$WORKER_DISK" &
PIDS[3]=$!
NAMES[3]="worker02"

# Monitor loop
SPINNER="-\|/"
while true; do
    RUNNING_COUNT=0
    STATUS_LINE=""
    FAILED_COUNT=0

    for i in 0 1 2 3; do
        if kill -0 "${PIDS[$i]}" 2>/dev/null; then
            STATUS_LINE+="${NAMES[$i]}: [⏳]   "
            RUNNING_COUNT=$((RUNNING_COUNT+1))
        else
            # Process finished, check status
            if [ -f "${LOGS_DIR}/${NAMES[$i]}.status" ]; then
                STATUS_CONTENT=$(cat "${LOGS_DIR}/${NAMES[$i]}.status")
                if [[ "$STATUS_CONTENT" == "Success" || "$STATUS_CONTENT" == "Exists" ]]; then
                    STATUS_LINE+="${NAMES[$i]}: [✅]   "
                else
                    STATUS_LINE+="${NAMES[$i]}: [❌]   "
                    FAILED_COUNT=$((FAILED_COUNT+1))
                fi
            else
                # Process finished but no status file? treating as failed/unknown or still verifying?
                # If kill -0 failed, process is gone. If no file, something crashed hard.
                STATUS_LINE+="${NAMES[$i]}: [?]   "
                FAILED_COUNT=$((FAILED_COUNT+1))
            fi
        fi
    done

    # Print status line and rewrite it
    echo -ne "\r${STATUS_LINE}"

    if [ "$RUNNING_COUNT" -eq 0 ]; then
        echo "" # New line
        if [ "$FAILED_COUNT" -gt 0 ]; then
             echo -e "${RED}>>> Error: Some VMs failed to create. Check logs in ${LOGS_DIR}.${NC}"
             exit 1
        fi
        break
    fi

    sleep 1
done
echo -e "\n${GREEN}>>> VM Creation phase complete.${NC}"
# Cleanup handled by trap when script exits

# Wait for network readiness (Wait until they have IPs and can reach internet)
echo -e "${BLUE}>>> Waiting for network readiness on all VMs...${NC}"
for vm in master01 master02 worker01 worker02; do
    (
        echo -e "Waiting for $vm network..."
        # Loop until we can ping 1.1.1.1
        multipass exec "$vm" -- timeout 120s bash -c "until ping -c1 1.1.1.1 &>/dev/null; do sleep 2; done"
        echo -e "${GREEN}>>> $vm is network ready.${NC}"
    ) &
done

wait

echo -e "${GREEN}>>> All VMs are network ready.${NC}"

# Configure /etc/hosts
echo -e "${BLUE}>>> Configuring /etc/hosts...${NC}"
HOST_ENTRIES_FILE=$(mktemp)
# Generate hosts file
echo "# BEGIN: K8S_LAB_HOSTS" > "$HOST_ENTRIES_FILE"
for vm in master01 master02 worker01 worker02; do
    ip=$(multipass info "$vm" --format json | jq -r ".info.${vm}.ipv4[0]")
    echo "${ip} ${vm}" >> "$HOST_ENTRIES_FILE"
done
echo "# END: K8S_LAB_HOSTS" >> "$HOST_ENTRIES_FILE"

# Apply hosts file in parallel
for vm in master01 master02 worker01 worker02; do
    (
        multipass transfer "$HOST_ENTRIES_FILE" "${vm}:/tmp/k8s_lab_hosts"
        multipass exec "$vm" -- sudo sed -i.bak '/# BEGIN: K8S_LAB_HOSTS/,/# END: K8S_LAB_HOSTS/d' /etc/hosts
        multipass exec "$vm" -- bash -c 'cat /tmp/k8s_lab_hosts | sudo tee -a /etc/hosts >/dev/null'
    ) &
done
wait
rm "$HOST_ENTRIES_FILE"
echo -e "${GREEN}>>> /etc/hosts configured on all nodes.${NC}"

# Function: create_vm_bundle
# Purpose: Compresses the project directory for transfer to VMs.
# Note: Uses 'COPYFILE_DISABLE=1' to prevent macOS from including metadata files (._*) which cause warnings on Linux.
echo -e "${BLUE}>>> Transferring Project Scripts (No Mounts = More Stability)...${NC}"

# Create the tarball
# --exclude: Prevent the tarball from including itself (recursive loop)
# --exclude: Skip macOS .DS_Store files to keep Linux environment clean
COPYFILE_DISABLE=1 tar --exclude='./k8s-lab-bundle.tar.gz' --exclude='.DS_Store' --exclude='.git' -czf "${PROJECT_DIR}/k8s-lab-bundle.tar.gz" -C "${PROJECT_DIR}" .
echo -e "${BLUE}>>> Tarball created. Distributing to VMs (one by one for stability)...${NC}"

# Sequential transfers to avoid overloading multipass daemon
for vm in master01 master02 worker01 worker02; do
    echo -ne ">>> Transferring to ${vm}... "

    # Create directories
    multipass exec "$vm" -- mkdir -p /home/ubuntu/k8s-lab
    multipass exec "$vm" -- mkdir -p /home/ubuntu/share

    # Transfer, extract, cleanup
    multipass transfer "${PROJECT_DIR}/k8s-lab-bundle.tar.gz" "${vm}:/home/ubuntu/k8s-lab-bundle.tar.gz"

    # Extract using bash to handle redirection properly inside the VM
    # This suppresses "Ignoring unknown extended header keyword" warnings from macOS tarballs
    multipass exec "$vm" -- bash -c "tar xzf /home/ubuntu/k8s-lab-bundle.tar.gz -C /home/ubuntu/k8s-lab 2>/dev/null"

    multipass exec "$vm" -- rm /home/ubuntu/k8s-lab-bundle.tar.gz

    # Make scripts executable
    multipass exec "$vm" -- find /home/ubuntu/k8s-lab -name "*.sh" -exec chmod +x {} \;

    echo "Done"
done

rm "${PROJECT_DIR}/k8s-lab-bundle.tar.gz"

echo -e "${GREEN}>>> Cluster VM setup complete! VMs are running, networked, and provisioned.${NC}"
