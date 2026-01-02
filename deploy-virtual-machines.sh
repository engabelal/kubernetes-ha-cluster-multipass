#!/bin/bash
set -euo pipefail

# =============================================================================
# Deploy Virtual Machines - Kubernetes Local Lab
# Purpose: Creates VMs and initializes ONLY the first control plane (master01).
#          Other nodes join manually for reliability.
# =============================================================================

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

# Directories
PROJECT_DIR="$(pwd)"
SHARE_DIR_HOST="${PROJECT_DIR}/_cluster_share"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}>>> Kubernetes Local Cluster Deployment${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "${YELLOW}Cluster Specification:${NC}"
echo -e "${YELLOW}  - Kubernetes Version       : v1.35.0${NC}"
echo -e "${YELLOW}  - Control Plane Nodes      : master01, master02${NC}"
echo -e "${YELLOW}  - Worker Nodes             : worker01, worker02${NC}"
echo -e "${YELLOW}Components (Manual Install): ${NC}"
echo -e "${YELLOW}  - CNI: Calico/Cilium/Flannel | Ingress: NGINX${NC}"
echo -e "${YELLOW}  - Metrics Server | Local Path Provisioner${NC}"
echo -e "${BLUE}=====================================================${NC}"
sleep 1

# Phase 1: Create VMs
echo -e "${GREEN}>>> Phase 1: Creating VMs...${NC}"
./00-multipass/create-vms.sh
echo -e "${GREEN}>>> VMs Ready.${NC}"

# Phase 2: Initialize master01
echo -e "${GREEN}>>> Phase 2: Initializing master01 (kubeadm init)...${NC}"
multipass exec master01 -- chmod +x /home/ubuntu/k8s-lab/01-bootstrap/master01-init-kubeadm.sh
multipass exec master01 -- /home/ubuntu/k8s-lab/01-bootstrap/master01-init-kubeadm.sh
echo -e "${GREEN}>>> master01 initialized.${NC}"

# Phase 3: Fetch join scripts to host
echo -e "${GREEN}>>> Phase 3: Fetching join scripts...${NC}"
mkdir -p "$SHARE_DIR_HOST"
multipass transfer master01:/home/ubuntu/share/master-join.sh "${SHARE_DIR_HOST}/master-join.sh"
multipass transfer master01:/home/ubuntu/share/worker-join.sh "${SHARE_DIR_HOST}/worker-join.sh"
echo -e "${GREEN}>>> Join scripts saved to ${SHARE_DIR_HOST}${NC}"

# Phase 4: Get kubeconfig
echo -e "${GREEN}>>> Phase 4: Fetching kubeconfig...${NC}"
multipass exec master01 -- cat /home/ubuntu/.kube/config > kubeconfig
MASTER_IP=$(multipass info master01 --format json | jq -r '.info.master01.ipv4[0]')
sed -i.bak "s/server: https:\/\/.*:6443/server: https:\/\/${MASTER_IP}:6443/" kubeconfig
rm -f kubeconfig.bak
echo -e "${GREEN}>>> kubeconfig saved to ./kubeconfig${NC}"

# Done - Print next steps
echo ""
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}>>> PHASE 1 COMPLETE: master01 is ready!${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""
echo -e "${YELLOW}>>> NEXT STEPS (Run these manually):${NC}"
echo ""
echo -e "${BLUE}# 1. Join master02 as control-plane:${NC}"
echo "multipass exec master02 -- sudo bash /home/ubuntu/share/master-join.sh"
echo ""
echo -e "${BLUE}# 2. Join workers:${NC}"
echo "multipass exec worker01 -- sudo bash /home/ubuntu/share/worker-join.sh"
echo "multipass exec worker02 -- sudo bash /home/ubuntu/share/worker-join.sh"
echo ""
echo -e "${BLUE}# 3. Label workers:${NC}"
echo "multipass exec master01 -- kubectl label node worker01 node-role.kubernetes.io/worker=worker"
echo "multipass exec master01 -- kubectl label node worker02 node-role.kubernetes.io/worker=worker"
echo ""
echo -e "${BLUE}# 4. Install Calico CNI:${NC}"
echo "multipass exec master01 -- bash -c 'helm repo add projectcalico https://docs.projectcalico.org/charts && helm repo update && helm upgrade --install calico projectcalico/tigera-operator --namespace tigera-operator --create-namespace --set installation.calicoNetwork.ipPools[0].cidr=10.244.0.0/16'"
echo ""
echo -e "${BLUE}# 5. Check cluster status:${NC}"
echo "export KUBECONFIG=\$(pwd)/kubeconfig"
echo "kubectl get nodes"
echo ""
echo -e "${YELLOW}>>> Full guide: MANUAL_COMMANDS.md${NC}"
echo -e "${BLUE}=====================================================${NC}"
