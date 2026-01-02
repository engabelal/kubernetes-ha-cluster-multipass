# Traefik Ingress Controller Installation

Traefik is a modern, cloud-native reverse proxy and load balancer. We'll install it using its official Helm chart.

## Installation with Helm

1.  **Add the Traefik Helm repository**:
    ```bash
    helm repo add traefik https://helm.traefik.io/traefik
    helm repo update
    ```

2.  **Install Traefik**:
    We will use a values file (`traefik-values.yaml`) to enable the dashboard and expose it via a `NodePort`.

    ```bash
    helm install traefik traefik/traefik -f 03-ingress/traefik-values.yaml --namespace traefik --create-namespace
    ```

3.  **Verify Installation**:
    Check that the Traefik pod is running in its own namespace:
    ```bash
    kubectl get pods -n traefik
    ```

## Accessing the Traefik Dashboard

The `traefik-values.yaml` file configures the dashboard to be accessible via a `NodePort`.

1.  **Find the Dashboard NodePort**:
    ```bash
    kubectl get svc -n traefik traefik
    ```
    Look for the port named `traefik` to find the dashboard's `NodePort`.

2.  **Access the Dashboard**:
    Open your browser and navigate to:
    `http://<WORKER_NODE_IP>:<DASHBOARD_NODE_PORT>`

    You will be able to see real-time information about routers, services, and middleware.
