# Session 17 — Networking

---

## Networking - Pod/Cluster Communication

- **Container-to-Container** — Pod/localhost communication
- **Pod-to-Pod** (East/West traffic)
- **Pod-to-Service** (East/West traffic)
- **External-to-Service** (North/South traffic)

**Terminology:**
- East-West Traffic — traffic within the cluster
- North-South Traffic — traffic from outside the cluster to inside

---

## K8s Network Model

**Networking Guidelines:**
- Pods can communicate with all other pods without requiring SNAT
- All node agents can communicate with pods on that node
- Every Pod gets its own IP address
- Isolation is defined using Network Policies (firewalls)

**Networking Solutions:**
- **Container-to-Container** in a pod — uses loopback interface, managed by CNI. Pods are assigned IP addresses by CNIs and all containers within a Pod communicate via localhost.
- **Pod-to-Pod & Pod-to-Service** — K8s has a Service API that lets you expose an application running within a Pod to be reachable from outside your cluster or within the cluster.

---

## CNI - Container Networking Interface

- Networking plugins based on a set of specifications
- Defines a contract that allows container runtimes to request a working IP address for a process on startup

**Functions:**
- IPAM — IP Address Management
  - ADD, DELETE & CHECK network interfaces to Pods
- Implement Network Policies (optional)

**Implementations:**
- Cilium (eBPF-based, recommended)
- Calico
- Flannel
- VPC-native (cloud provider CNIs — GKE, EKS)
- Weave Net

---

## Service (SVC)

> **Analogy:** A ClusterIP service is like a call center phone number — the number never changes, but the agents (pods) answering calls can be swapped out at any time.

- An abstraction that exposes a group of pods over a network
- Provides a single, stable access point (virtual IP) to a set of pods
- Targets pods using a **selector** (similar to pod controllers)
- Clients connect to the service without needing to know backend pod IPs
- Backend pods can be scaled up/down transparently

---

## Cluster Networking Overview

Traffic enters the cluster through a Cloud Load Balancer, hits a NodePort, and kube-proxy's iptables/IPVS rules route it to an individual Pod:

```
External Client
      │
      ▼
┌──────────┐
│ Cloud LB │ ← LoadBalancer Service
└────┬─────┘
     ▼
┌──────────┐
│ NodePort │ ← NodePort Service
└────┬─────┘
     ▼
┌──────────┐
│kube-proxy│ ← iptables/IPVS rules
└────┬─────┘
     ├──► Pod A (10.0.1.5)
     ├──► Pod B (10.0.2.7)
     └──► Pod C (10.0.3.2)
```

---

## Service Types

| Type | Description |
|------|-------------|
| **ClusterIP** (default) | Internal stable IP. East-west traffic only |
| **NodePort** | Exposes on each node's IP at a static port (30000-32767) |
| **LoadBalancer** (L4) | Provisions an external cloud load balancer (AWS NLB, GCP LB, Azure LB) |
| **ExternalName** | Maps service to an external CNAME DNS record |
| **Headless** | ClusterIP = None. No load balancing. A records created for backend pods. Used when you need direct pod addressing (StatefulSets) |

> **Headless Service analogy:** Unlike a regular service (one front-desk number), a Headless Service gives you the direct desk phone for every employee. You choose who to call.

**Service type decision guide:**
- **Internal communication** between pods → ClusterIP
- **Dev/debug access** from outside the cluster → NodePort
- **Cloud production** external traffic → LoadBalancer
- **HTTP routing, path-based rules, TLS termination** → Ingress or Gateway API (Session 18)

---

## Service Spec

```yaml
spec:
  type: ClusterIP          # default
  selector:
    app: my-app
  ports:
    - name: http            # name for the port
      port: 80              # service port
      targetPort: 8080      # container port (number or named port)
      protocol: TCP         # default is TCP
      appProtocol: http
      # nodePort: 30080     # only for NodePort/LoadBalancer
  externalTrafficPolicy: Local  # preserves original client IP (NodePort/LoadBalancer only)
```

> **`externalTrafficPolicy: Local`** — when set, kube-proxy only forwards traffic to pods on the same node. This preserves the original client IP (no SNAT), but requires pods to be spread across nodes to avoid traffic black-holing.

**Creating Services:**
```bash
# Imperative
kubectl expose deployment <name> --name <svc-name> --port=80 --target-port=8080

# Connect to a service
kubectl port-forward svc/<svc_name> <local_port>:<svc_port>
```

---

## Service without Selectors

- Creates a Service without a corresponding endpoint
- Use Cases: connect to an endpoint outside the cluster
- Requires manually creating an Endpoint (or EndpointSlice) with the external IP
- Labels needed to pair: `kubernetes.io/service-name: <service name>`

---

## Endpoints & EndpointSlices

**Endpoints:**
- Defines a list of network endpoints referenced by a Service
- Has a limit of storing 1000 endpoints

**EndpointSlices:**
- Represents a subset of backing network endpoints for a Service
- New EndpointSlices created when count reaches 100
- Scalable and extensible alternative to Endpoints
- Contains topology information

---

## Service Discovery

**Environment Variables:**
- At Pod creation, kubelet adds env vars for each active service:
  - `{SVCNAME}_SERVICE_HOST`
  - `{SVCNAME}_SERVICE_PORT`

**DNS (preferred):**
- CoreDNS (cluster add-on)
- Generates A record & SRV record for each service
- Format: `<svc_name>.<svc_namespace>.svc.cluster.local`
- Headless Service — A records created for backend pods directly
- ExternalName — maps a K8s service to an external CNAME

---

## DNS Resolution Flow

How a pod resolves a service name and reaches a backend pod:

```
Pod A needs to call "my-svc"
  │
  ▼ resolves my-svc.default.svc.cluster.local
  │
  ▼ CoreDNS returns ClusterIP (10.96.0.15)
  │
  ▼ kube-proxy iptables routes to a Pod IP
  │
  ▼ Pod B (10.0.2.7) receives the request
```

---

## KubeProxy

- Present on all nodes as a node-agent
- Manipulates iptables so packets reach backend pods when destined for a service
- Does NOT route network packets directly
- Watches for changes to Services + Endpoints/EndpointSlices and updates iptables

**Modes:**
- **iptables** — default, uses kernel iptables rules
- **IPVS** — better performance at scale, L4 load balancing
- **eBPF** (Cilium) — bypasses iptables entirely, highest performance

**Scaling guidance:**
- Under ~1000 services, iptables is fine.
- Beyond that, IPVS scales better due to hash-based lookups vs linear iptables rules.
- Cilium's eBPF eliminates kube-proxy entirely, offering the best performance and observability at any scale.

---

## Network Policies (NETPOL)

- Used to control traffic flow at the IP address level
- Implemented by the network plugin (CNI) — not all CNIs support Network Policies
- Without any Network Policy, all traffic is allowed (default allow)

**Policy Types:**
- **Ingress** — controls incoming traffic to pods
- **Egress** — controls outgoing traffic from pods

**Policy Selectors:**
- `ipBlock` — CIDR ranges
- `namespaceSelector` — select by namespace labels
- `podSelector` — select by pod labels

**Best Practice:** Start with a default-deny policy, then explicitly allow required traffic.

---

## Network Policy: Default Deny

Block all ingress and egress for all pods in the namespace. Apply this first, then layer in allow rules.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}       # matches all pods in the namespace
  policyTypes:
    - Ingress
    - Egress
```

---

## Network Policy: Allow from Specific Namespace

Allow ingress to pods labeled `app: backend` only from pods in a namespace labeled `team: frontend`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend-namespace
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              team: frontend
```

> To label a namespace: `kubectl label namespace frontend-ns team=frontend`

---

## Key Takeaways

- Every Pod gets a unique IP; Services provide a stable virtual IP in front of a dynamic set of pods.
- **ClusterIP** for internal traffic, **NodePort** for dev access, **LoadBalancer** for cloud production, **Ingress/Gateway API** for HTTP routing.
- **Headless Services** expose individual pod DNS records — essential for StatefulSets that need stable, addressable identities.
- **CoreDNS** resolves service names to ClusterIPs; kube-proxy's iptables/IPVS rules handle the final hop to a pod.
- **kube-proxy modes**: iptables is fine up to ~1000 services; IPVS scales better beyond that; Cilium eBPF eliminates kube-proxy entirely.
- Set `externalTrafficPolicy: Local` to preserve the original client IP on NodePort/LoadBalancer services.
- **Default-deny NetworkPolicy** is your baseline — apply it to every namespace, then explicitly open only required traffic paths.
- CNI choice determines whether NetworkPolicies are enforced at all — Flannel does not support them; Cilium and Calico do.
