# Project Overview

## Project Overview

This project provides a set of shell scripts to automate the deployment and deletion of a local Kubernetes cluster using `multipass` and `kubeadm`. It's designed for macOS and simplifies the process of setting up a multi-node cluster for development and testing purposes.

The cluster consists of a control plane and a configurable number of worker nodes. The scripts can create the cluster in two network modes:

*   **BRIDGE:** VMs are placed on the local network, making them accessible from the host machine and other devices on the same network.
*   **NAT:** VMs are placed in a private virtual network. Access to services running in the cluster requires setting up port forwarding.

## Building and Running

### Prerequisites

*   [multipass](https://multipass.run/install)
*   [jq](https://stedolan.github.io/jq/download/)

### Deploying the Cluster

To deploy the fully automated cluster (including VMs, Kubernetes, CNI, Ingress, and Metrics), simply run:

```bash
./deploy-virtual-machines.sh
```

The script runs in parallel and handles everything for you. No extra flags are needed.

### Deleting the Cluster

To delete the cluster and release the resources, run the following command:

```bash
./00-multipass/destroy-vms.sh
```

**Note:** After deleting the VMs, the script will prompt you to manually remove the DHCP leases for the deleted VMs from `/var/db/dhcpd_leases`.

## Development Conventions

The project consists of two main shell scripts:

*   `deploy-virtual-machines.sh`: This orchestrator script handles the parallel creation of VMs, generates join tokens, and uses **Helm** to install Calico, Ingress, Metrics Server, and storage.
*   `00-multipass/destroy-vms.sh`: This script stops and deletes the virtual machines.

The scripts are written in `bash` and use `multipass` for VM management. They are designed to be run from the project's root directory.
