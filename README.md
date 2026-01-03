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

*   **Nodes (VMs)**:
    *   `master01`, `master02` (Control Plane)
    *   `worker01`, `worker02` (Data Plane)
    *   `haproxy` (Load Balancer) **[NEW]**
*   **Networking**:
    *   **Pod CIDR**: `10.244.0.0/16`
    *   **Service CIDR**: `10.96.0.0/12`
    *   **External Access**: HAProxy (VIP) -> Ingress Controller (NodePort) -> Services.

```text
       +-----------------+
       |  User / Laptop  |
       +--------+--------+
                |
                v
    [ HAProxy Load Balancer ]
    ( 192.168.x.x )
                |
      +---------+---------+
      |                   |
      v                   v
+------------+     +-------------+
| K8s API    |     | Web Traffic |
| (Port 6443)|     | (Port 80/443)|
+-----+------+     +------+------+
      |                   |
+-----+------+     +------+------+
|   MASTERS  |     |   WORKERS   |
+------------+     +-------------+
```

## Prerequisites

*   **Host OS**: A modern Linux distribution or macOS.
*   **Multipass**: [Install Multipass](https://multipass.run/install).
*   **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) on your host machine to interact with the cluster.

## Automated Deployment (Recommended)

For a full "Zero to Hero" deployment, run the scripts in this order:

### 1. Deploy Kubernetes Cluster
```bash
chmod +x 01-deploy-virtual-machines.sh
./01-deploy-virtual-machines.sh
```
*This bootstraps the HA cluster, installs CNI, Ingress, and Metrics Server.*

### 2. Deploy Load Balancer (Optional but Recommended)
For a production-like experience, deploy the dedicated HAProxy VM:
```bash
chmod +x 02-deploy-haproxy-vm.sh
./02-deploy-haproxy-vm.sh
```
*   Follow the **[HAProxy Guide](./HAPROXY_GUIDE.md)** to configure routing rules.
*   Once configured, you can access the cluster API and Applications via the HAProxy IP.

### 3. Verify Deployment
You can use the example manifest to test the flow (HAProxy -> Ingress -> POD):

```bash
kubectl apply -f examples/test-whoami.yaml
```

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

To interact with your cluster from your host machine using `kubectl`, you need the `kubeconfig` file. The `01-deploy-virtual-machines.sh` script automatically creates this for you.

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
| **Deploy** | `./01-deploy-virtual-machines.sh` |
| **Start** | `./03-start-cluster.sh` |
| **Stop** | `./04-stop-cluster.sh` |
| **Destroy** | `./05-destroy-cluster.sh` |
| **Snapshot** | `./06-snapshot-cluster.sh` |
| **Restore** | `./07-restore-cluster.sh` |

> **Note:**
> *   **Start/Stop**: Maintains VMs and data.
> *   **Snapshot**: Takes a synchronized snapshot of ALL nodes (requires stopping the cluster).
> *   **Restore**: Reverts the entire cluster to a previous state (DATA LOSS of changes made after snapshot).
> *   **Destroy**: Deletes everything.

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
