#!/bin/bash
# =============================================================================
# Start Kubernetes Cluster (Correct Sequence)
# Purpose: Start all VMs in the correct order for K8s cluster
# =============================================================================

set -euo pipefail

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${YELLOW}>>> Starting Kubernetes Cluster...${NC}"

# 1. Start Load Balancer (Optional)
if multipass list | grep -q "haproxy"; then
    echo -e "${GREEN}>>> Step 1: Starting HAProxy Load Balancer...${NC}"
    multipass start haproxy 2>/dev/null || echo -e "${YELLOW}>>> HAProxy already running.${NC}"
    sleep 5
else
    echo -e "${YELLOW}>>> Step 1: HAProxy VM not found. Skipping.${NC}"
fi

# 2. Start Primary Control Plane First
echo -e "${GREEN}>>> Step 2: Starting master01 (primary control plane)...${NC}"
multipass start master01
echo -e "${GREEN}>>> Waiting for master01 to be ready...${NC}"
sleep 10

# 3. Start Secondary Control Plane
echo -e "${GREEN}>>> Step 3: Starting master02...${NC}"
multipass start master02
sleep 5

# 4. Start Workers Last
echo -e "${GREEN}>>> Step 4: Starting worker nodes...${NC}"
multipass start worker01 worker02
sleep 5

echo ""
echo -e "${GREEN}>>> All VMs started!${NC}"
multipass list

# 5. Wait for cluster to be healthy
echo ""
echo -e "${YELLOW}>>> Waiting for cluster to become healthy...${NC}"
sleep 10

# 6. Check cluster status
echo -e "${GREEN}>>> Checking cluster status...${NC}"
multipass exec master01 -- kubectl get nodes 2>/dev/null || echo -e "${YELLOW}>>> Cluster still initializing, wait a moment and check manually.${NC}"

echo ""
echo -e "${GREEN}>>> Cluster started successfully!${NC}"
echo -e "${YELLOW}>>> To stop the cluster, run: ./04-stop-cluster.sh${NC}"
