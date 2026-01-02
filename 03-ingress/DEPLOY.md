# Step 4: Install an Ingress Controller

An Ingress controller is needed to expose HTTP and HTTPS routes from outside the cluster to services within the cluster. This guide provides instructions for installing either **Ingress-NGINX** or **Traefik**. You should only install one.

**Note:** Before proceeding, ensure you have a working `kubeconfig` file on your host machine as described in the main `README.md`. All `kubectl` commands from this point on should be run from your **host machine**.

## Option 1: Install Ingress-NGINX (Recommended for CKA/CKAD)

Ingress-NGINX is a widely used Ingress controller and is relevant for Kubernetes certification exams.

### 1. Apply the Manifest

The manifest will create the `ingress-nginx` namespace and deploy the controller as a `NodePort` service, making it accessible via your worker nodes' IPs.

```bash
kubectl apply -f 03-ingress/ingress-nginx.yaml
```

### 2. Verify the Installation

Check that the Ingress controller pod is running:
```bash
kubectl get pods -n ingress-nginx
```
Wait for the pod to reach the `Running` state.

For more details on how to use it, see the [Ingress-NGINX Notes](./ingress-nginx-notes.md).

---

## Option 2: Install Traefik

Traefik is a modern and powerful cloud-native Ingress controller. We will install it using its official Helm chart.

### 1. Install Traefik with Helm

This command will install Traefik into its own `traefik` namespace using the provided Helm values, which enable the dashboard and expose the service via `NodePort`.

**Prerequisite**: You must have [Helm](https://helm.sh/docs/intro/install/) installed on your host machine.

```bash
# Add the Traefik Helm repo
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Install Traefik
helm install traefik traefik/traefik -f 03-ingress/traefik-values.yaml --namespace traefik --create-namespace
```

### 2. Verify the Installation

Check that the Traefik pod is running:
```bash
kubectl get pods -n traefik
```

For more details on how to access the dashboard and use Traefik, see the [Traefik Install Notes](./traefik-install-notes.md).

## Next Step

With an Ingress controller running, you can now manage traffic into your cluster. The final core component to install is the Metrics Server.

**[Next: Step 5 - Install Metrics Server](../04-metrics/DEPLOY.md)**
