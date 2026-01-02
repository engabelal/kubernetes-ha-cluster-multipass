#!/bin/bash
set -euo pipefail

# Colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
NC="\033[0m"

echo -e "${BLUE}>>> Deploying HAProxy Load Balancer VM...${NC}"

# 1. Launch VM
if multipass info haproxy >/dev/null 2>&1; then
    echo -e "${GREEN}>>> VM 'haproxy' already exists.${NC}"
else
    echo -e "${BLUE}>>> Launching 'haproxy' (1CPU, 1GB RAM)...${NC}"
    multipass launch 24.04 --name haproxy --cpus 1 --memory 1G --disk 5G
    echo -e "${GREEN}>>> VM Launched.${NC}"
fi

# 2. Install HAProxy
echo -e "${BLUE}>>> Updating system and installing HAProxy...${NC}"
multipass exec haproxy -- sudo apt-get update
multipass exec haproxy -- sudo apt-get upgrade -y
multipass exec haproxy -- sudo apt-get install -y haproxy vim
echo -e "${GREEN}>>> System updated. HAProxy and Vim installed.${NC}"

# 3. Add to /etc/hosts on Host
echo -e "${BLUE}>>> Configuring host /etc/hosts...${NC}"
IP=$(multipass info haproxy --format json | jq -r '.info.haproxy.ipv4[0]')
# Remove old entry if exists
sudo sed -i.bak "/haproxy/d" /etc/hosts
# Add new entry
echo "$IP haproxy" | sudo tee -a /etc/hosts > /dev/null
echo -e "${GREEN}>>> Added '$IP haproxy' to /etc/hosts.${NC}"

echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}>>> HAProxy VM Ready!${NC}"
echo -e "${BLUE}>>> Next Step: Follow 'HAPROXY_GUIDE.md' to configure it.${NC}"
echo -e "${BLUE}==============================================${NC}"
