# Calico CNI Installation

Calico is a widely used, high-performance Container Network Interface (CNI) for Kubernetes.

## Installation

The `kubeadm` cluster was configured with a Pod CIDR of `10.244.0.0/16`, which is the default for Calico. The official Calico manifest will automatically detect and use this CIDR.

1.  **Apply the Manifest**:
    From a node with `kubectl` access (like `master01`), run:
    ```bash
    kubectl apply -f /home/ubuntu/k8s-lab/02-cni/calico.yaml
    ```
    Alternatively, apply it directly from the source:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
    ```

2.  **Verify Installation**:
    Wait a few minutes for the Calico components to be deployed. Check the status of the pods in the `calico-system` namespace:
    ```bash
    kubectl get pods -n calico-system
    ```
    You should see pods like `calico-kube-controllers`, `calico-node`, and `calico-typha` in a `Running` state.

3.  **Check Node Status**:
    Once Calico is running, the cluster nodes should transition to the `Ready` state.
    ```bash
    kubectl get nodes
    ```
    The `STATUS` column for all nodes should now be `Ready`.
