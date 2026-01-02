# HAProxy Load Balancer Guide (Beginner Friendly)

This guide will help you configure a dedicated **Load Balancer** for your Kubernetes cluster.

## What is a Load Balancer?

Think of a Load Balancer (LB) as a **Receptionist** for your cluster.
- Instead of talking to `master01` or `master02` directly, you talk to the **Receptionist** (`haproxy`).
- The Receptionist forwards your request to whoever is available.
- If `master01` is sick (down), the Receptionist automatically sends you to `master02`.

### Architecture Diagram

```text
       +-----------------+
       |  User / Laptop  |
       +--------+--------+
                |
                v
    [ HAProxy Load Balancer ]
    ( 192.168.x.x )
                |
      +---------+---------+
      |                   |
      v                   v
+------------+     +-------------+
| K8s API    |     | Web Traffic |
| (Port 6443)|     | (Port 80/443)|
+-----+------+     +------+------+
      |                   |
+-----+------+     +------+------+
|   MASTERS  |     |   WORKERS   |
+------------+     +-------------+
```

We will configure HAProxy to handle **three** types of traffic:
1.  **Cluster Management (API)**: Port `6443` -> Forwards to Master Nodes.
2.  **Web Applications (HTTP)**: Port `80` -> Forwards to Worker Nodes.
3.  **Secure Web Apps (HTTPS)**: Port `443` -> Forwards to Worker Nodes.

---

## Step 1: Deploy the VM

Run the script to create the VM and install the HAProxy software:

```bash
chmod +x 02-deploy-haproxy-vm.sh
./02-deploy-haproxy-vm.sh
```

---

## Step 2: Configure HAProxy

Now we need to tell the receptionist the "rules".

### 1. Get IP Addresses & Ports
Run these commands on your mac terminal:

**Get Node IPs:**
```bash
multipass list
```
*Take note of the IPs for `master01`, `master02`, `worker01`, and `worker02`.*

**Get Ingress Ports:**
```bash
multipass exec master01 -- kubectl get svc -n ingress-nginx ingress-nginx-controller
```
*Look for `80:XXXXX` and `443:YYYYY`. You will need these numbers (NodePorts).*

### 2. Edit Configuration

We will append the rules to the **END** of the file.

Login to the HAProxy VM and open the file using **Vim**:

```bash
multipass exec haproxy -- sudo vim /etc/haproxy/haproxy.cfg
```

**Vim Quick Guide:**
1.  Press `G` (Capital G) to go to the very bottom of the file.
2.  Press `o` (Small o) to open a new line and enter **Insert Mode**.
3.  Paste the configuration below.
4.  Press `Esc`, then type `:wq` and hit `Enter` to save and exit.

### 3. Add the Rules
**Copy and paste this ENTIRE block at the BOTTOM of the file.**
**IMPORTANT**: Replace the IPs (`192.168.x.x`) and Ports (`30xxx`, `31xxx`) with your REAL values.

```haproxy
# ---------------------------------------------------------------------
# FRONTEND: The part that listens for incoming connections
# BACKEND: The group of servers to send traffic to
# ---------------------------------------------------------------------

# --- Rule 1: Kubernetes API (Control Plane) ---
# Listens on port 6443 and sends traffic to Masters
frontend k8s_api_frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s_api_backend

backend k8s_api_backend
    mode tcp
    option tcp-check
    balance roundrobin
    # REPLACE WITH REAL MASTER IPs
    server master01 192.168.64.2:6443 check fall 3 rise 2
    server master02 192.168.64.3:6443 check fall 3 rise 2

# --- Rule 2: Web Traffic HTTP (Ingress 80) ---
frontend http_frontend
    bind *:80
    mode tcp
    option tcplog
    default_backend http_backend

backend http_backend
    mode tcp
    balance roundrobin
    # REPLACE WITH REAL WORKER IPs AND NODEPORT for HTTP (e.g. 30183)
    server worker01 192.168.64.4:30183 check
    server worker02 192.168.64.5:30183 check

# --- Rule 3: Web Traffic HTTPS (Ingress 443) ---
frontend https_frontend
    bind *:443
    mode tcp
    option tcplog
    default_backend https_backend

backend https_backend
    mode tcp
    balance roundrobin
    # REPLACE WITH REAL WORKER IPs AND NODEPORT for HTTPS (e.g. 31967)
    server worker01 192.168.64.4:31967 check
    server worker02 192.168.64.5:31967 check
```

---

## Step 3: Restart HAProxy

Apply the new settings:

```bash
multipass exec haproxy -- sudo systemctl restart haproxy
```

Check strictly for errors:
```bash
multipass exec haproxy -- sudo systemctl status haproxy
```
*If it's Active (running), you are good!*

---

## Step 4: Validate Everything (Checklist)

Run these checks to ensure your Load Balancer is rock solid.

### 1 Check Configuration Validity
Before restarting, always check if your config is correct:
```bash
multipass exec haproxy -- sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```
✅ **Expected Output**: `Configuration file is valid`

### 2. Check Service Status
Ensure the service is active and running:
```bash
multipass exec haproxy -- sudo systemctl status haproxy
```
✅ **Expected Output**: `Active: active (running)`

### 3. Test Connectivity (From your Mac)

**A. API Server (Port 6443)**
Check if you can reach the Kubernetes API:
```bash
HAPROXY_IP=$(multipass info haproxy --format json | jq -r '.info.haproxy.ipv4[0]')
curl -k -I https://$HAPROXY_IP:6443/livez
```
✅ **Expected Output**: `HTTP/2 200` or `HTTP/1.1 200 OK`

**B. HTTP App (Port 80)**
Check if HTTP traffic reaches the Ingress Controller:
```bash
curl -I http://$HAPROXY_IP
```
✅ **Expected Output**: `HTTP/1.1 404 Not Found`
*(This is GOOD! It means Nginx replied "I am here, but I don't know what page you want". If you get "Connection refused", HAProxy failed to connect).*

**C. HTTPS App (Port 443)**
Check if HTTPS traffic reaches the Ingress Controller:
```bash
curl -k -I https://$HAPROXY_IP
```
✅ **Expected Output**: `HTTP/1.1 404 Not Found`
*(Again, this confirms Nginx is reachable over SSL).*

---

## Troubleshooting

1.  **"Connection Refused" when checking stats?**
    - Check if `haproxy` service is running (`systemctl status haproxy`).
    - Check if you used the correct NodePorts in `haproxy.cfg`.

2.  **"503 Service Unavailable"?**
    - HAProxy is running, but it cannot reach the backend servers (Masters or Workers).
    - Check if the IPs in `haproxy.cfg` are correct.
    - Check if the NodePorts on the Workers are actually open (`kubectl get svc -n ingress-nginx`).

### 1. Ingress NGINX Configuration (Proxy Protocol)
By default, the setup above works perfectly. However, logs will show the **HAProxy IP** as the source, not the real user's IP.

**To preserve the Real User IP:**
1.  **HAProxy**: Add `send-proxy` to the worker server lines in `haproxy.cfg`:
    ```haproxy
    server worker01 192.168.64.4:30183 check send-proxy
    server worker02 192.168.64.5:30183 check send-proxy
    ```
    *(Do this for both HTTP and HTTPS backends)*

2.  **Ingress NGINX**: Update the ConfigMap to accept Proxy Protocol.
    ```bash
    multipass exec master01 -- kubectl edit configmap -n ingress-nginx ingress-nginx-controller
    ```
    Add/Update the data section:
    ```yaml
    data:
      use-proxy-protocol: "true"
    ```

### 2. Gateway API
If you are using Gateway API, map the Frontend ports (80/443) to the **NodePort** exposed by your Gateway Service.

---

## Troubleshooting

1.  **HAProxy fails to start?**
    - You probably have a typo in `haproxy.cfg`.
    - Check config validity: `multipass exec haproxy -- sudo haproxy -c -f /etc/haproxy/haproxy.cfg`

2.  **Connection Refused?**
    - Check if the IPs in the config match the current `multipass list` IPs.
    - Check if the Ports (6443, NodePort) are correct.
