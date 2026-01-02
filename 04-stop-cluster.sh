#!/bin/bash
# =============================================================================
# Stop Kubernetes Cluster (Correct Sequence)
# Purpose: Gracefully stop all VMs in the correct order
# =============================================================================

set -euo pipefail

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${YELLOW}>>> Stopping Kubernetes Cluster...${NC}"

# 1. Stop Workers First (they depend on control plane)
echo -e "${GREEN}>>> Step 1: Stopping worker nodes...${NC}"
multipass stop worker02 worker01 --time 30 2>/dev/null || true
echo -e "${GREEN}>>> Workers stopped.${NC}"

# 2. Stop Secondary Control Plane
echo -e "${GREEN}>>> Step 2: Stopping master02...${NC}"
multipass stop master02 --time 30 2>/dev/null || true
echo -e "${GREEN}>>> master02 stopped.${NC}"

# 3. Stop Primary Control Plane (last)
echo -e "${GREEN}>>> Step 3: Stopping master01...${NC}"
multipass stop master01 --time 30 2>/dev/null || true
echo -e "${GREEN}>>> master01 stopped.${NC}"

echo ""
echo -e "${GREEN}>>> All VMs stopped successfully!${NC}"
echo -e "${YELLOW}>>> To start the cluster, run: ./start-cluster.sh${NC}"

multipass list
