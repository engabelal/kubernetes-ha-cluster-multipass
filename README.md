# Kubernetes Local Lab with Kubeadm and Multipass

This project provides a complete, production-style local Kubernetes lab environment using `kubeadm` and Multipass. It's designed for learning and practicing for certifications like CKA/CKAD, as well as for testing real-world DevOps workflows.

The lab sets up a high-availability (HA) control plane with two masters and two worker nodes.

## Table of Contents
1.  [Features](#features)
2.  [Cluster Architecture](#cluster-architecture)
3.  [Prerequisites](#prerequisites)
4.  [Step-by-Step Installation Guide](#step-by-step-installation-guide)
5.  [Connecting to the Cluster](#connecting-to-the-cluster)
6.  [Managing the Lab](#managing-the-lab)
7.  [Troubleshooting](#troubleshooting)
8.  [Stacked Etcd Explained](#stacked-etcd-explained)

## Features

*   **Kubernetes Version**: 1.35.0.
*   **High-Availability Control Plane**: 2 control-plane nodes (`master01`, `master02`).
*   **Worker Nodes**: 2 worker nodes (`worker01`, `worker02`).
*   **Virtualization**: [Multipass](https://multipass.run/) for lightweight Ubuntu VMs.
*   **Provisioning**: `kubeadm` for cluster bootstrapping.
*   **Container Runtime**: `containerd`.
*   **CNI**: [Calico](https://www.tigera.io/project-calico/) (via Helm).
*   **Ingress**: [Ingress-NGINX](https://kubernetes.github.io/ingress-nginx/) (via Helm).
*   **Metrics**: `metrics-server` (via Helm).
*   **Storage**: [Rancher Local Path Provisioner](https://github.com/rancher/local-path-provisioner) for default local storage.

## Cluster Architecture

*   **VMs**: 4 Ubuntu 24.04 VMs.
    *   `master01` (2 CPUs, 4GB RAM, 20GB Disk)
    *   `master02` (2 CPUs, 4GB RAM, 20GB Disk)
    *   `worker01` (2 CPUs, 2GB RAM, 20GB Disk)
    *   `worker02` (2 CPUs, 2GB RAM, 20GB Disk)
*   **Networking**:
    *   **Pod CIDR**: `10.244.0.0/16`
    *   **Service CIDR**: `10.96.0.0/12`
*   **Control Plane**:
    *   Stacked `etcd`: Each control-plane node runs its own `etcd` instance, which is part of the cluster's `etcd` ring.
    *   The API server endpoint is initially on `master01`. In a real production scenario, a dedicated load balancer would sit in front of the control-plane nodes.

## Prerequisites

*   **Host OS**: A modern Linux distribution or macOS.
*   **Multipass**: [Install Multipass](https://multipass.run/install).
*   **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) on your host machine to interact with the cluster.

## Automated Deployment (Recommended)

For a fully automated, zero-manual-intervention deployment of the entire Kubernetes lab, simply execute the `deploy-virtual-machines.sh` script from the root of this repository on your host machine:

```bash
chmod +x deploy-virtual-machines.sh
./deploy-virtual-machines.sh
```

This script will:
1.  Create the Multipass VMs and mount the project directory.
2.  Bootstrap the Kubernetes cluster with `kubeadm`.
3.  Install Calico CNI.
4.  Install Ingress-NGINX.
5.  Install Metrics Server.
6.  Automatically retrieve and configure the `kubeconfig` on your host.

## Step-by-Step Installation Guide

For manual deployment with detailed explanations for each step:

| Step | Description |
|------|-------------|
| [Step 1](./00-multipass/DEPLOY.md) | Provision Virtual Machines |
| [Step 2](./01-bootstrap/DEPLOY.md) | Bootstrap the Kubernetes Cluster |
| [Step 3](./02-cni/DEPLOY.md) | Install the CNI (Calico) |
| [Step 4](./03-ingress/DEPLOY.md) | Install an Ingress Controller |
| [Step 5](./04-metrics/DEPLOY.md) | Install Metrics Server |

> **Quick Reference:** For copy-paste commands, see **[COMMANDS.md](./COMMANDS.md)**

## Connecting to the Cluster

To interact with your cluster from your host machine using `kubectl`, you need the `kubeconfig` file. The `deploy-virtual-machines.sh` script automatically creates this for you.

1.  **Export the `KUBECONFIG` variable**:
    ```bash
    export KUBECONFIG=$(pwd)/kubeconfig
    ```

2.  **Test your connection**:
    ```bash
    kubectl get nodes
    ```

## Optional: Update Host's /etc/hosts for Easy VM Access

To be able to `ping master01` or `ssh ubuntu@worker01` directly from your host terminal, you can add the VM IPs to your local `/etc/hosts` file.

**Note:** These scripts must be run with `sudo` because they modify a system file (`/etc/hosts`).

*   **To ADD the entries**:
    Run this script after your VMs have been created. It will automatically find the VM IPs and add them to `/etc/hosts`. The script is idempotent and can be re-run safely.

    ```bash
    sudo ./05-host-setup/update-hosts-file.sh
    ```

*   **To REMOVE the entries**:
    Run this script to clean up `/etc/hosts` when you are done with the lab.

    ```bash
    sudo ./05-host-setup/remove-hosts-file-entries.sh
    ```


## Managing the Lab

| Action | Command |
|--------|---------|
| **Deploy** | `./deploy-virtual-machines.sh` |
| **Start** | `./start-cluster.sh` |
| **Stop** | `./stop-cluster.sh` |
| **Destroy** | `./destroy-cluster.sh` |

> **Note:** Start/Stop maintains VMs and data. Destroy deletes everything.

## Troubleshooting

*   **`kubeadm init` fails**:
    - Ensure `containerd` is running (`systemctl status containerd`).
    - Check for typos in `kubeadm-config.yaml`.
    - Run `kubeadm reset -f` on `master01` before trying again.
*   **Node join fails**:
    - Ensure the token has not expired. You can generate a new one on `master01` with `kubeadm token create --print-join-command`.
    - Check for network connectivity between the nodes.
*   **Nodes are `NotReady`**:
    - The CNI is likely not installed or not working correctly. Check the `calico-system` pods (`kubectl get pods -n calico-system`).
*   **CoreDNS pods are not running**:
    - This is almost always a CNI issue. Once the CNI is healthy, CoreDNS should start.
*   **`kubectl top` returns an error**:
    - Ensure `metrics-server` is installed and the pods are running in the `kube-system` namespace.
    - Check the logs of the `metrics-server` pod for errors.

## Stacked Etcd Explained

**Stacked etcd** means that the `etcd` database runs on the same nodes as the Kubernetes control plane components (like `kube-apiserver`). In our setup, `master01` and `master02` both run an `etcd` member, and these members form a distributed cluster.

*   **Advantages**: Easy to set up with `kubeadm`, no need for extra VMs for `etcd`.
*   **Disadvantages**: Tightly couples control plane and `etcd` lifecycle. Loss of a control-plane node also means loss of an `etcd` member.
*   **Quorum**: With only two `etcd` members, this cluster is **not resilient to failure**. If one `etcd` node goes down, the cluster will lose quorum and go into a read-only state. A production `etcd` cluster requires a minimum of 3 members to be fault-tolerant. This 2-node setup is for lab purposes only.

**Checking etcd Health**:

You can check `etcd` health from one of the master nodes.

1.  **List etcd pods**:
    ```bash
    multipass exec master01 -- kubectl get pods -n kube-system | grep etcd
    ```

2.  **Use `etcdctl`**:
    `kubeadm` ships `etcdctl`. You can use it to query the cluster status.
    ```bash
    multipass exec master01 -- bash -c 'ETCDCTL_API=3 etcdctl --endpoints="https://127.0.0.1:2379" --cacert="/etc/kubernetes/pki/etcd/ca.crt" --cert="/etc/kubernetes/pki/etcd/server.crt" --key="/etc/kubernetes/pki/etcd/server.key" endpoint health --cluster'
    ```
