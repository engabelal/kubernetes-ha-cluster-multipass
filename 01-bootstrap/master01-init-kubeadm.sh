#!/bin/bash
set -euo pipefail

# Define shared directory inside the VM
SHARE_DIR="/home/ubuntu/share"

echo ">>> Initializing Kubernetes cluster on master01..."

# Check if already initialized
if [ -f "/etc/kubernetes/admin.conf" ]; then
    echo ">>> Cluster already initialized. Skipping 'kubeadm init'."
else
    # Initialize the control plane using the kubeadm-config.yaml
    # --upload-certs is critical for joining other control-plane nodes
    sudo kubeadm init --config=/home/ubuntu/k8s-lab/01-bootstrap/kubeadm-config.yaml --upload-certs
    echo ">>> Kubeadm init complete."
fi

echo ">>> Generating/Refreshing join scripts..."

# Ensure target directory exists
mkdir -p "$SHARE_DIR"

# 1. Generate Worker Join Command
echo ">>> Generating worker-join.sh..."
WORKER_JOIN_CMD=$(sudo kubeadm token create --print-join-command)
echo "#!/bin/bash" > "${SHARE_DIR}/worker-join.sh"
echo "sudo ${WORKER_JOIN_CMD}" >> "${SHARE_DIR}/worker-join.sh"
chmod +x "${SHARE_DIR}/worker-join.sh"

# 2. Generate Control Plane Join Command
# We need a fresh certificate key for security and robustness
echo ">>> Generating master-join.sh..."
CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs | tail -1)
# Re-use the token or create a new one? Creating a new one is safer to ensure we have the full command.
# But we can just append the cert key to the worker command + --control-plane
echo "#!/bin/bash" > "${SHARE_DIR}/master-join.sh"
echo "sudo ${WORKER_JOIN_CMD} --control-plane --certificate-key ${CERT_KEY}" >> "${SHARE_DIR}/master-join.sh"
chmod +x "${SHARE_DIR}/master-join.sh"

echo ">>> Join scripts generated in ${SHARE_DIR}:"
ls -l "${SHARE_DIR}"

# Set up kubeconfig for the ubuntu user
echo ">>> Setting up kubeconfig for ubuntu user..."
mkdir -p /home/ubuntu/.kube
sudo cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo ">>> Cluster initialization complete on master01."
