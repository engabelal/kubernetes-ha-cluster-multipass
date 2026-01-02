# Optional CNI: Cilium Installation

Cilium is a modern, powerful CNI that uses eBPF for networking, observability, and security.

**IMPORTANT**: Do not install Cilium if you have already installed Calico. If you wish to switch, you must first uninstall Calico.

## Uninstalling Calico (If Applicable)

If you have already installed Calico, you must remove it completely before installing Cilium.

```bash
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

## Installing Cilium with Helm

The recommended way to install Cilium is with Helm.

1.  **Add the Cilium Helm repository**:
    ```bash
    helm repo add cilium https://helm.cilium.io/
    ```

2.  **Install Cilium**:
    Run the `helm install` command. Cilium will automatically detect the cluster's Pod CIDR.
    ```bash
    helm install cilium cilium/cilium --version 1.18.0 \
      --namespace kube-system \
      --set-string extraConfig.auto-direct-node-routes=true \
      --set ipam.operator.clusterPoolIPv4PodCIDR="10.244.0.0/16"
    ```
    *Note: We are using a hypothetical version 1.18.0 for compatibility with Kubernetes 1.35. Always check the official Cilium documentation for the correct version to use with your Kubernetes release.*

3.  **Verify Installation**:
    Check that the Cilium pods are running in the `kube-system` namespace.
    ```bash
    kubectl get pods -n kube-system | grep cilium
    ```

4.  **Check Connectivity**:
    Cilium provides a connectivity test to ensure everything is working correctly.
    ```bash
    cilium connectivity test
    ```
    (You may need to install the `cilium-cli` for this command).
