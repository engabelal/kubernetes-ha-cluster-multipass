# Step 3: Install the CNI (Calico)

A Container Network Interface (CNI) plugin is required for pods to communicate across nodes. This step installs Calico, a popular and powerful CNI.

Once the CNI is installed, your nodes will transition to a `Ready` state, and CoreDNS and other cluster components will become fully operational.

## 1. Apply the Calico Manifest

From your host machine, you can use `multipass exec` to run `kubectl` on `master01` and apply the Calico manifest. The manifest is located in the `02-cni` directory inside the repository you cloned onto the VM.

```bash
# Apply the manifest from within master01
multipass exec master01 -- kubectl apply -f /home/ubuntu/k8s-lab/02-cni/calico.yaml
```
*Replace `your-repo-name` with the name of the directory where you cloned the project.*

Alternatively, you can apply it directly from the official source URL:
```bash
multipass exec master01 -- kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

## 2. Verify the Installation

It will take a few minutes for the Calico components to be deployed and start running on all nodes.

You can monitor the status of the Calico pods from `master01`:
```bash
multipass exec master01 -- kubectl get pods -n calico-system
```
Wait until all pods in the `calico-system` namespace show a `STATUS` of `Running`.

## 3. Confirm Node Status

Once Calico is healthy, all nodes in the cluster should report a `Ready` status.

Verify this from `master01`:
```bash
multipass exec master01 -- kubectl get nodes
```
The output should now look like this:
```
NAME       STATUS   ROLES           AGE   VERSION
master01   Ready    control-plane   15m   v1.35.0
master02   Ready    control-plane   13m   v1.35.0
worker01   Ready    <none>          11m   v1.35.0
worker02   Ready    <none>          10m   v1.35.0
```

## Alternative CNI: Cilium

This project uses Calico by default. If you prefer to use Cilium, see the separate guide here:
*   **[Cilium Installation Guide](./cilium-install-notes.md)**

## Next Step

Your cluster is now fully functional. The next step is to install an Ingress controller to manage external access to your applications.

**[Next: Step 4 - Install an Ingress Controller](../03-ingress/DEPLOY.md)**
