# Ingress-NGINX Installation

Ingress-NGINX is a popular Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer.

## Installation

We will use the official manifest for bare-metal clusters, which exposes the Ingress controller via a `NodePort` service.

1.  **Apply the Manifest**:
    ```bash
    kubectl apply -f 03-ingress/ingress-nginx.yaml
    ```
    This will create the `ingress-nginx` namespace and all required resources.

2.  **Verify Installation**:
    Check that the Ingress controller pod is running:
    ```bash
    kubectl get pods -n ingress-nginx
    ```
    You should see a pod named `ingress-nginx-controller-...` in the `Running` state.

3.  **Check the Service**:
    The Ingress controller is exposed via a `NodePort` service. Find the assigned ports with:
    ```bash
    kubectl get svc -n ingress-nginx
    ```
    You will see output like this, showing the mapping from port 80 and 443 to high-numbered node ports (e.g., 3xxxx).

    ```
    NAME                                 TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
    ingress-nginx-controller             NodePort   10.101.123.45   <none>        80:32080/TCP,443:32443/TCP   6m
    ingress-nginx-controller-admission   ClusterIP  10.102.54.32    <none>        443/TCP                      6m
    ```

## How to Access

To access services exposed via Ingress, you can use the IP of any of your **worker nodes** and the `NodePort` assigned to the HTTP/HTTPS service.

*   **URL**: `http://<WORKER_NODE_IP>:<HTTP_NODE_PORT>`

Example: If `worker01` has the IP `192.168.64.10` and the HTTP NodePort is `32080`, you would access your services at `http://192.168.64.10:32080`.
