# Step 2: Bootstrap the Kubernetes Cluster

This step uses `kubeadm` to initialize the cluster on `master01` and join the remaining nodes.

**Note**: The `create-vms.sh` script automatically mounted this project directory into each VM at `/home/ubuntu/k8s-lab`. The scripts are now ready to be executed from within the VMs without needing to be manually copied.

## 1. Initialize the Control Plane on `master01`

Run the initialization script inside `master01`. This will configure it as the first control-plane node.

```bash
# Make the script executable
multipass exec master01 -- chmod +x /home/ubuntu/k8s-lab/01-bootstrap/master01-init-kubeadm.sh

# Run the init script
multipass exec master01 -- /home/ubuntu/k8s-lab/01-bootstrap/master01-init-kubeadm.sh
```

### **CRITICAL: Save the Join Commands**

The output of this script will contain two `kubeadm join` commands. **You must copy these commands immediately.** They are required to join the other nodes to the cluster.

The output will look similar to this:

```
...
Your Kubernetes control-plane has initialized successfully!
...
Then you can join any number of worker nodes by running the following on each as root:

  kubeadm join master01:6443 --token abcdef.1234567890abcdef \
	--discovery-token-ca-cert-hash sha256:1234...

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join master01:6443 --token abcdef.1234567890abcdef \
	--discovery-token-ca-cert-hash sha256:1234... \
	--control-plane --certificate-key 5678...
```

## 2. Join the Second Control-Plane Node (`master02`)

Use the `kubeadm join` command with the `--control-plane` flag that you just saved. Execute it inside `master02`.

```bash
# Execute the join command inside master02
multipass exec master02 -- sudo <PASTE_THE_CONTROL_PLANE_JOIN_COMMAND_HERE>
```

## 3. Join the Worker Nodes (`worker01` and `worker02`)

Use the other `kubeadm join` command (the one without the `--control-plane` flag) to join the two worker nodes.

```bash
# Join worker01
multipass exec worker01 -- sudo <PASTE_THE_WORKER_JOIN_COMMAND_HERE>

# Join worker02
multipass exec worker02 -- sudo <PASTE_THE_WORKER_JOIN_COMMAND_HERE>
```

## 4. Verify the Cluster

From `master01`, you can now check the status of your nodes.

```bash
multipass exec master01 -- kubectl get nodes
```

All four nodes should be listed. They will be in a `NotReady` state because the network CNI has not been installed yet.

```
NAME       STATUS     ROLES           AGE   VERSION
master01   NotReady   control-plane   5m    v1.35.0
master02   NotReady   control-plane   3m    v1.35.0
worker01   NotReady   <none>          1m    v1.35.0
worker02   NotReady   <none>          30s   v1.35.0
```

## 5. Label Worker Nodes (Optional but Recommended)

By default, worker nodes don't have a role label. To label them as "worker" for better visibility:

```bash
# Label worker01
kubectl label node worker01 node-role.kubernetes.io/worker=worker

# Label worker02
kubectl label node worker02 node-role.kubernetes.io/worker=worker
```

Or run from your host:
```bash
multipass exec master01 -- kubectl label node worker01 node-role.kubernetes.io/worker=worker
multipass exec master01 -- kubectl label node worker02 node-role.kubernetes.io/worker=worker
```

After labeling, `kubectl get nodes` will show:
```
NAME       STATUS   ROLES           AGE   VERSION
master01   Ready    control-plane   10m   v1.35.0
master02   Ready    control-plane   8m    v1.35.0
worker01   Ready    worker          5m    v1.35.0
worker02   Ready    worker          4m    v1.35.0
```

## Next Step

The cluster nodes are now joined, but they cannot communicate with each other yet. The next step is to install the CNI plugin.

**[Next: Step 3 - Install the CNI (Calico)](../02-cni/DEPLOY.md)**
