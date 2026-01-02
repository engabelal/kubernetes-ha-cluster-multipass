# Manual Cluster Commands Reference

This file contains ready-to-run commands for completing the cluster setup after `master01` is initialized.

---

## 1. Check Cluster Status

```bash
# See all nodes
multipass exec master01 -- kubectl get nodes

# Watch nodes live
multipass exec master01 -- kubectl get nodes -w
```

---

## 2. Join Nodes to Cluster

### Option A: Get Fresh Join Commands from master01

```bash
# Get worker join command
multipass exec master01 -- kubeadm token create --print-join-command

# Get control-plane join command (includes certificate-key)
multipass exec master01 -- bash -c "kubeadm token create --print-join-command; kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1"
```

### Option B: Execute Join (Copy from master01 output)

**Join master02 as Control Plane:**
```bash
multipass exec master02 -- sudo kubeadm join master01:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane \
  --certificate-key <CERT_KEY>
```

**Join worker01:**
```bash
multipass exec worker01 -- sudo kubeadm join master01:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

**Join worker02:**
```bash
multipass exec worker02 -- sudo kubeadm join master01:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### Quick Join (Using existing join scripts)
If scripts exist in `/home/ubuntu/share`:

```bash
# Join master02
multipass exec master02 -- sudo bash /home/ubuntu/share/master-join.sh

# Join workers
multipass exec worker01 -- sudo bash /home/ubuntu/share/worker-join.sh
multipass exec worker02 -- sudo bash /home/ubuntu/share/worker-join.sh
```

---

## 3. Label Worker Nodes

```bash
multipass exec master01 -- kubectl label node worker01 node-role.kubernetes.io/worker=worker
multipass exec master01 -- kubectl label node worker02 node-role.kubernetes.io/worker=worker
```

---

## 4. Install CNI (Choose ONE)

### Option A: Calico (Recommended)
```bash
multipass exec master01 -- bash -c "
helm repo add projectcalico https://docs.projectcalico.org/charts
helm repo update
helm upgrade --install calico projectcalico/tigera-operator \
  --namespace tigera-operator --create-namespace \
  --version v3.31.3 \
  --set installation.calicoNetwork.ipPools[0].cidr=10.244.0.0/16
"
```

### Option B: Cilium
```bash
multipass exec master01 -- bash -c "
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.5 \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true
"
```

#### Install Cilium CLI (Optional - for advanced management)
```bash
# Install on master01
multipass exec master01 -- bash -c '
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
'

# Verify Cilium status with CLI
multipass exec master01 -- cilium status
multipass exec master01 -- cilium connectivity test  # Full connectivity test
```

### Option C: Flannel
```bash
multipass exec master01 -- kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

> **🔧 Flannel Troubleshooting: "address already in use" Error**
>
> If Flannel pods show Error with `failed to set interface flannel.1 to UP state: address already in use`:
> 1. Delete Flannel first and wait for namespace to terminate:
>    ```bash
>    kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
>    kubectl get ns kube-flannel -w  # Wait until deleted
>    ```
> 2. Clean interfaces on ALL nodes:
>    ```bash
>    for NODE in master01 master02 worker01 worker02; do
>      multipass exec $NODE -- bash -c 'sudo ip link delete flannel.1 2>/dev/null; sudo rm -rf /etc/cni/net.d/* /var/lib/cni/ /run/flannel 2>/dev/null; true'
>    done
>    ```
> 3. Reinstall Flannel:
>    ```bash
>    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
>    ```

### ✅ Validate CNI
```bash
# Check all nodes are Ready
multipass exec master01 -- kubectl get nodes

# For Calico: Check tigera-operator and calico-system pods
multipass exec master01 -- kubectl get pods -n tigera-operator
multipass exec master01 -- kubectl get pods -n calico-system

# For Cilium: Check cilium pods
multipass exec master01 -- kubectl get pods -n kube-system -l k8s-app=cilium
multipass exec master01 -- kubectl exec -n kube-system ds/cilium -- cilium status

# For Flannel: Check flannel pods
multipass exec master01 -- kubectl get pods -n kube-flannel
multipass exec master01 -- kubectl get pods -n kube-system -l app=flannel

# Test pod networking (create test pods)
multipass exec master01 -- kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
multipass exec master01 -- kubectl exec test-pod -- ping -c 3 8.8.8.8
multipass exec master01 -- kubectl delete pod test-pod
```

### 🗑️ Uninstall CNI

> **⚠️ Node Cleanup Required:** After uninstalling CNI, residual configs may remain on nodes.
> Run these on **EACH node** (master01, master02, worker01, worker02) if switching CNI:

```bash
# Uninstall Calico (from master01)
multipass exec master01 -- helm uninstall calico -n tigera-operator
multipass exec master01 -- kubectl delete namespace tigera-operator calico-system

# Uninstall Cilium (from master01)
multipass exec master01 -- helm uninstall cilium -n kube-system

# Uninstall Flannel (from master01)
multipass exec master01 -- kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Optional: Clean CNI residue on EACH node (run if switching CNI)
for NODE in master01 master02 worker01 worker02; do
  multipass exec $NODE -- bash -c 'sudo rm -rf /etc/cni/net.d/* 2>/dev/null || true'
  multipass exec $NODE -- bash -c 'sudo rm -rf /var/lib/cni/ 2>/dev/null || true'
  multipass exec $NODE -- bash -c 'sudo ip link delete cni0 2>/dev/null || true'
  multipass exec $NODE -- bash -c 'sudo ip link delete flannel.1 2>/dev/null || true'
  multipass exec $NODE -- bash -c 'sudo ip link delete cilium_host 2>/dev/null || true'
done
```

---

## 5. Install Metrics Server

### Option A: Using Helm (Recommended)
```bash
multipass exec master01 -- bash -c "
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.13.0 \
  --set 'args[0]=--kubelet-insecure-tls' \
  --set 'args[1]=--kubelet-preferred-address-types=InternalIP'
"
```

### Option B: Using kubectl apply (Alternative)
```bash
# Download and patch the manifest
multipass exec master01 -- bash -c "
curl -sL https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | \
  sed 's/args:/args:\n        - --kubelet-insecure-tls\n        - --kubelet-preferred-address-types=InternalIP/' | \
  kubectl apply -f -
"
```

> **Note:** `--kubelet-insecure-tls` is required for kubeadm clusters with self-signed certs.
> `--kubelet-preferred-address-types=InternalIP` helps when nodes have multiple IPs.

### ✅ Validate Metrics Server
```bash
# Check deployment status
multipass exec master01 -- kubectl get deployment metrics-server -n kube-system

# Check pods are running
multipass exec master01 -- kubectl get pods -n kube-system -l k8s-app=metrics-server

# Test metrics API (wait 1-2 min after install)
multipass exec master01 -- kubectl top nodes
multipass exec master01 -- kubectl top pods -A

# Check API availability
multipass exec master01 -- kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

### 🗑️ Uninstall Metrics Server
```bash
multipass exec master01 -- helm uninstall metrics-server -n kube-system
```

---

## 6. Install Ingress Controller

### NGINX Ingress
```bash
multipass exec master01 -- bash -c "
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.14.1 \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=NodePort
"
```

### ✅ Validate Ingress Controller
```bash
# Check pods are running
multipass exec master01 -- kubectl get pods -n ingress-nginx

# Check service
multipass exec master01 -- kubectl get svc -n ingress-nginx

# Check ingress class is available
multipass exec master01 -- kubectl get ingressclass

# Test with a sample ingress (optional)
multipass exec master01 -- kubectl get ingress -A
```

### 🗑️ Uninstall Ingress Controller
```bash
multipass exec master01 -- helm uninstall ingress-nginx -n ingress-nginx
multipass exec master01 -- kubectl delete namespace ingress-nginx
```

---

## 7. Install MetalLB (LoadBalancer for Bare Metal)

> **⚠️ Multipass on macOS Compatibility:**
> MetalLB L2 mode works with Multipass **only if using bridged networking**.
> Default NAT mode = MetalLB IPs not accessible from host.
> To check: `multipass list` - if IPs are in 192.168.x.x range, you're likely bridged.

### Install MetalLB
```bash
multipass exec master01 -- bash -c "
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace \
  --version 0.15.3 \
  --wait
"
```

### Configure IP Pool (L2 Mode)
First, find your VM IP range:
```bash
# Get VM IPs to determine the range
multipass list
# Example: If VMs are 192.168.64.2-5, use 192.168.64.200-192.168.64.250 for LoadBalancer
```

Apply configuration:
```bash
# Replace IP range with one matching your network!
multipass exec master01 -- bash -c "
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: local-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.64.200-192.168.64.250  # CHANGE THIS to your network range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: local-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - local-pool
EOF
"
```

### ✅ Validate MetalLB
```bash
# Check MetalLB pods
multipass exec master01 -- kubectl get pods -n metallb-system

# Check IP pools
multipass exec master01 -- kubectl get ipaddresspools -n metallb-system

# Test LoadBalancer service
multipass exec master01 -- bash -c "
kubectl create deployment nginx-lb-test --image=nginx
kubectl expose deployment nginx-lb-test --port=80 --type=LoadBalancer
sleep 5
kubectl get svc nginx-lb-test
"

# Cleanup test
multipass exec master01 -- kubectl delete deployment nginx-lb-test
multipass exec master01 -- kubectl delete svc nginx-lb-test
```

### 🗑️ Uninstall MetalLB
```bash
multipass exec master01 -- kubectl delete -n metallb-system ipaddresspools --all
multipass exec master01 -- kubectl delete -n metallb-system l2advertisements --all
multipass exec master01 -- helm uninstall metallb -n metallb-system
multipass exec master01 -- kubectl delete namespace metallb-system
```

---

## 8. Install Local Storage Provisioner

```bash
multipass exec master01 -- bash -c "
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'
"
```

### ✅ Validate Storage
```bash
# Check StorageClass
multipass exec master01 -- kubectl get storageclass

# Check provisioner pod
multipass exec master01 -- kubectl get pods -n local-path-storage

# Test PVC creation
multipass exec master01 -- bash -c "
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
EOF
"
multipass exec master01 -- kubectl get pvc test-pvc
multipass exec master01 -- kubectl delete pvc test-pvc
```

### 🗑️ Uninstall Storage Provisioner
```bash
multipass exec master01 -- kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

---

## 9. Get Kubeconfig to Host

```bash
multipass exec master01 -- cat /home/ubuntu/.kube/config > kubeconfig

# Update server IP
MASTER_IP=$(multipass info master01 --format json | jq -r '.info.master01.ipv4[0]')
sed -i.bak "s/server: https:\/\/.*:6443/server: https:\/\/${MASTER_IP}:6443/" kubeconfig

# Use it
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

---

## 10. Destroy Cluster

```bash
./00-multipass/destroy-vms.sh
```

---

## 11. 🔍 Full Cluster Validation (All Components)

Run this after deploying everything to validate the entire cluster:

```bash
echo "=== 1. Nodes Status ==="
multipass exec master01 -- kubectl get nodes -o wide

echo -e "\n=== 2. System Pods ==="
multipass exec master01 -- kubectl get pods -n kube-system

echo -e "\n=== 3. CNI Status ==="
multipass exec master01 -- kubectl get pods -n calico-system 2>/dev/null || \
multipass exec master01 -- kubectl get pods -n kube-system -l k8s-app=cilium 2>/dev/null || \
echo "CNI: Flannel or other"

echo -e "\n=== 4. Metrics Server ==="
multipass exec master01 -- kubectl top nodes 2>/dev/null || echo "Metrics not ready"

echo -e "\n=== 5. Ingress Controller ==="
multipass exec master01 -- kubectl get pods -n ingress-nginx

echo -e "\n=== 6. Storage Classes ==="
multipass exec master01 -- kubectl get storageclass

echo -e "\n=== 7. CoreDNS Test ==="
multipass exec master01 -- kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes

echo -e "\n=== 8. Cluster Info ==="
multipass exec master01 -- kubectl cluster-info
```

---

## 12. 🔍 Check etcd Health (Stacked on Control Plane)

etcd runs on each control-plane node (stacked topology). Check health on all masters:

### Install etcdctl (if not available)
```bash
# etcdctl is usually bundled with kubeadm, but if you need to install it:
multipass exec master01 -- bash -c '
ETCD_VER=v3.5.17
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; elif [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd.tar.gz
sudo tar xzf /tmp/etcd.tar.gz -C /tmp
sudo mv /tmp/etcd-${ETCD_VER}-linux-${ARCH}/etcdctl /usr/local/bin/
rm -rf /tmp/etcd*
etcdctl version
'
```

### Check etcd Pods
```bash
# List etcd pods on all control-plane nodes
multipass exec master01 -- kubectl get pods -n kube-system -l component=etcd -o wide
```

### Check etcd Cluster Members
```bash
# Run from master01 (will show all members including master02)
multipass exec master01 -- sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table
```

### Check etcd Endpoint Health (All Members)
```bash
# Get IPs for both masters first
MASTER01_IP=$(multipass info master01 --format json | jq -r '.info.master01.ipv4[0]')
MASTER02_IP=$(multipass info master02 --format json | jq -r '.info.master02.ipv4[0]')

# Check health of all endpoints
multipass exec master01 -- sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://${MASTER01_IP}:2379,https://${MASTER02_IP}:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health -w table
```

### Verify etcd on Each Master
```bash
# Check etcd on master01
multipass exec master01 -- sudo crictl ps | grep etcd

# Check etcd on master02
multipass exec master02 -- sudo crictl ps | grep etcd
```

### Quick etcd Status Script
```bash
echo "=== etcd Pods ==="
multipass exec master01 -- kubectl get pods -n kube-system -l component=etcd

echo -e "\n=== etcd Cluster Members ==="
multipass exec master01 -- sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

echo -e "\n=== etcd Running on master01? ==="
multipass exec master01 -- sudo crictl ps --name etcd

echo -e "\n=== etcd Running on master02? ==="
multipass exec master02 -- sudo crictl ps --name etcd
```

> **Note:** With 2 etcd members, you have NO fault tolerance. If either master fails, etcd loses quorum. For production, use 3+ control-plane nodes.
