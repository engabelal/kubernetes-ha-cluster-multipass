# Step 1: Provision Virtual Machines

This step creates the four virtual machines required for the Kubernetes cluster using Multipass.

## 1. Make the Script Executable

First, ensure the `create-vms.sh` script has execute permissions.

```bash
chmod +x 00-multipass/create-vms.sh
```

## 2. Run the VM Creation Script

Execute the script from the root of the repository. This will:
- Launch four Ubuntu 24.04 VMs (`master01`, `master02`, `worker01`, `worker02`).
- Apply a `cloud-init` configuration to each VM to install `containerd`, `kubeadm`, and other necessary tools.
- Automatically update the `/etc/hosts` file on each VM so they can resolve each other by name.

```bash
./00-multipass/create-vms.sh
```
This process may take several minutes as it downloads the Ubuntu image and runs the setup scripts.

## 3. Verify VM Creation

Once the script is complete, verify that all four VMs are running and have been assigned IP addresses.

```bash
multipass list
```

You should see output similar to this:

```
Name        State     IPv4             Image
master01    Running   192.168.64.2     Ubuntu 24.04 LTS
master02    Running   192.168.64.3     Ubuntu 24.04 LTS
worker01    Running   192.168.64.4     Ubuntu 24.04 LTS
worker02    Running   192.168.64.5     Ubuntu 24.04 LTS
```

## Next Step

The virtual machines are now ready. Proceed to the next step to bootstrap the Kubernetes cluster.

**[Next: Step 2 - Bootstrap the Kubernetes Cluster](../01-bootstrap/DEPLOY.md)**
