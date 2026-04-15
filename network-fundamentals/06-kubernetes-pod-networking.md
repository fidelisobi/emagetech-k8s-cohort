# 🔌 Kubernetes Networking — How Pods Talk to Each Other

> **Pre-req:** Make sure you've read [01-what-is-a-network.md](01-what-is-a-network.md) first.

---

## Everything You Learned, Applied to Kubernetes

In the networking basics tutorials, you learned that every device on a network gets an IP address, and that packets travel between them. Kubernetes builds a network on top of your infrastructure — and it works the same way, just at container scale.

---

## Every Pod Gets Its Own IP

In Kubernetes, the basic unit of work is a **Pod** (one or more containers running together).

Just like your laptop has an IP address on your home network, **every Pod gets its own IP address** on the cluster network.

```
Node 1 (192.168.1.10):
  ├── Pod A  → 10.244.0.5
  └── Pod B  → 10.244.0.6

Node 2 (192.168.1.11):
  ├── Pod C  → 10.244.1.3
  └── Pod D  → 10.244.1.4
```

Any Pod can reach any other Pod by IP — even if they're on different physical nodes.
This is the **flat network model** Kubernetes requires.

---

## The Problem: Pod IPs Are Temporary

Here's the catch: **Pod IPs change**.

When a Pod crashes and restarts, it gets a NEW IP. When you scale from 1 replica to 3, you get 3 different IPs. You can't hardcode an IP in your app — it'll break.

This is exactly the problem DNS solved on the internet. And Kubernetes solves it the same way.

---

## Services — Stable Addresses for Pods

A **Service** is a stable virtual IP address (called ClusterIP) that always points to a group of Pods.

```
Pods:                           Service:
  Pod A → 10.244.0.5  ──┐
  Pod B → 10.244.0.6  ──┼──→  my-app-service → 10.96.0.50
  Pod C → 10.244.1.3  ──┘
```

Even if Pod A dies and comes back as Pod D with a new IP, the Service IP (`10.96.0.50`) never changes.

Your app talks to the Service — the Service handles routing to healthy Pods.

This is exactly how a **load balancer** works on the regular internet!

---

## Service Types

| Type | What It Does | When to Use |
|------|-------------|-------------|
| **ClusterIP** | Internal only, reachable inside the cluster | Default; app-to-app communication |
| **NodePort** | Exposes a port on every node's IP | Dev/testing access from outside |
| **LoadBalancer** | Provisions a cloud load balancer with a public IP | Production external traffic |
| **ExternalName** | Maps to an external DNS name | Pointing to external services |

---

## Kubernetes DNS — Services Get Names

Remember how DNS maps `google.com` → `142.250.80.46`?

Kubernetes has its own DNS server (**CoreDNS**) that gives every Service a name:

```
<service-name>.<namespace>.svc.cluster.local
```

Example:
```
my-app-service.default.svc.cluster.local
```

Inside the cluster, your app can just use:
```
http://my-app-service
```
...and CoreDNS resolves it to the ClusterIP automatically.

```bash
# Inside a Pod, you can verify DNS works:
kubectl exec -it my-pod -- nslookup my-app-service
kubectl exec -it my-pod -- curl http://my-app-service
```

---

## Ports in Kubernetes

Every container exposes ports, just like a web server listens on port 80.

In a Pod spec:
```yaml
containers:
  - name: web
    image: nginx
    ports:
      - containerPort: 80    # the port INSIDE the container
```

In a Service spec:
```yaml
spec:
  ports:
    - port: 80          # port the Service listens on (inside cluster)
      targetPort: 80    # port on the Pod to forward to
      nodePort: 30080   # (NodePort only) port on the Node
```

---

## 🧪 Try It Yourself

```bash
# See all Services and their ClusterIPs
kubectl get services -A

# See all Pod IPs
kubectl get pods -o wide

# Describe a Service (shows endpoints / Pod IPs it routes to)
kubectl describe service my-service

# Test DNS resolution from inside a pod
kubectl run tmp --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default
```

---

## ✅ What You Learned

- Every Pod gets an IP — but those IPs are temporary
- Services provide stable IPs that load-balance across Pods
- CoreDNS gives Services human-readable names
- Ports in Kubernetes work the same as regular ports — containers expose them, Services route to them

**Next:** [Network Policies — Firewalls for Pods →](07-network-policies-k8s.md)
