# Metrics Server Installation

The Metrics Server collects resource usage data from each node's Kubelet and exposes it through the Kubernetes Metrics API. This is what powers `kubectl top nodes` and `kubectl top pods`.

## Installation

For `kubeadm`-based clusters, the Kubelet serves metrics over a TLS endpoint with a self-signed certificate that is not trusted by the main cluster CA. Therefore, we must instruct the Metrics Server to skip TLS verification when communicating with the Kubelets.

The provided `metrics-server.yaml` is the official manifest patched with the `--kubelet-insecure-tls` argument.

1.  **Apply the Manifest**:
    ```bash
    kubectl apply -f 04-metrics/metrics-server.yaml
    ```

2.  **Verify Installation**:
    Check that the `metrics-server` pod is running in the `kube-system` namespace.
    ```bash
    kubectl get pods -n kube-system | grep metrics-server
    ```

## Verification

After a minute or two, the Metrics Server will begin collecting data.

1.  **Check Node Metrics**:
    ```bash
    kubectl top nodes
    ```
    You should see CPU and memory usage for each node in the cluster.

2.  **Check Pod Metrics**:
    ```bash
    kubectl top pods -A
    ```
    This command will show CPU and memory usage for all pods across all namespaces. If it returns metrics, the server is working correctly.
