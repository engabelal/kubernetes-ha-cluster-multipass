# Step 5: Install Metrics Server

The Metrics Server is a cluster-wide aggregator of resource usage data. It's a crucial component that enables commands like `kubectl top nodes` and `kubectl top pods`, which are essential for monitoring and troubleshooting.

**Note:** Ensure you have a working `kubeconfig` file on your host machine. All `kubectl` commands should be run from your **host machine**.

## 1. Apply the Patched Manifest

The provided `metrics-server.yaml` manifest is based on the official version but includes a necessary patch for `kubeadm`-based clusters. It adds the `--kubelet-insecure-tls` flag, which allows the Metrics Server to communicate with the Kubelets on each node, as they use self-signed certificates.

```bash
kubectl apply -f 04-metrics/metrics-server.yaml
```

## 2. Verify the Installation

Check that the `metrics-server` deployment is running in the `kube-system` namespace.

```bash
kubectl get deployment metrics-server -n kube-system
```

## 3. Test the Metrics API

It may take a minute or two for the Metrics Server to start collecting data from all the nodes.

You can verify that it's working by running `kubectl top`:

```bash
# Check resource usage for nodes
kubectl top nodes
```

If the command returns CPU and memory usage for each node, the installation was successful.

```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master01   100m         5%     1200Mi          30%
master02   95m          4%     1150Mi          29%
worker01   50m          2%     450Mi           22%
worker02   55m          2%     460Mi           23%
```

You can also check pod-level metrics:
```bash
kubectl top pods -A
```

## Next Step

Congratulations! You have deployed a complete, multi-node Kubernetes cluster with networking, ingress, and metrics.

Refer back to the main **[Deployment Guide](../DEPLOYMENT.md)** or the **[README.md](../README.md)** for information on how to use and manage your new lab environment.
