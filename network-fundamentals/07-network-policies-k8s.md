# 🛡️ Network Policies — Firewalls for Pods

> **Pre-req:** Read [03-ports-and-protocols.md](03-ports-and-protocols.md) and [06-kubernetes-pod-networking.md](06-kubernetes-pod-networking.md) first.

---

## Kubernetes is Open by Default

By default, every Pod in a Kubernetes cluster can talk to every other Pod.
No restrictions. No questions asked.

This is convenient for development — but dangerous in production.

Imagine your database Pod is reachable from EVERY Pod, including ones that have nothing to do with it. If an attacker compromises any Pod, they can hit your database directly.

---

## Network Policies — Kubernetes Firewalls

A **NetworkPolicy** is a Kubernetes resource that acts like a firewall rule: it controls which Pods are allowed to send traffic to which other Pods.

Think back to the firewall rules from the networking tutorial:
```
ALLOW TCP port 443 from anywhere
DENY  everything else
```

NetworkPolicies work the same way, but for Pod-to-Pod traffic.

---

## How Network Policies Work

NetworkPolicies use **labels** to select which Pods they apply to.

```
app=frontend  ──→  app=backend   ✅ allowed (NetworkPolicy permits this)
app=logging   ──→  app=backend   ❌ blocked (no policy allows this)
```

---

## A Real Example

**Goal:** Only allow the `frontend` Pod to talk to the `backend` Pod on port 8080.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend        # This policy applies TO backend Pods
  policyTypes:
    - Ingress             # We're controlling incoming traffic
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend   # Only allow traffic FROM frontend Pods
      ports:
        - protocol: TCP
          port: 8080
```

**What this does:**
- Selects all Pods with label `app=backend`
- Only allows incoming traffic from Pods with label `app=frontend`
- Only on TCP port 8080
- Everything else is denied

---

## Default Deny — The Gold Standard

Best practice: **deny all traffic by default**, then explicitly allow only what's needed.

```yaml
# Deny ALL ingress traffic to all Pods in this namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}        # {} = select ALL pods
  policyTypes:
    - Ingress
```

Then add specific allow policies on top.

---

## Ingress vs. Egress

| Direction | Meaning | Example |
|-----------|---------|---------|
| **Ingress** | Traffic coming INTO a Pod | Who can call my API? |
| **Egress** | Traffic going OUT of a Pod | Which databases can my app reach? |

```yaml
# Only allow backend pods to talk to the database on port 5432
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
```

---

## ⚠️ Important: You Need a CNI Plugin

NetworkPolicies are defined in Kubernetes, but they're **enforced by the network plugin** (CNI).

If your cluster uses a CNI that doesn't support NetworkPolicies (like the default `kubenet`), the policies will be created but have **no effect**.

CNI plugins that support NetworkPolicies:
- **Calico** ✅ (most popular)
- **Cilium** ✅ (advanced, eBPF-based)
- **Weave** ✅
- **Flannel** ❌ (no NetworkPolicy support by default)

GKE, EKS, and AKS all support NetworkPolicies when configured correctly.

---

## 🧪 Try It Yourself

```bash
# List all NetworkPolicies in the cluster
kubectl get networkpolicies -A

# Describe a specific one
kubectl describe networkpolicy allow-frontend-to-backend

# Apply the default-deny policy
kubectl apply -f default-deny.yaml

# Test connectivity between pods
kubectl exec -it frontend-pod -- curl http://backend-service:8080
kubectl exec -it logging-pod -- curl http://backend-service:8080   # should fail
```

---

## ✅ What You Learned

- Kubernetes is open by default — NetworkPolicies lock it down
- NetworkPolicies use label selectors (not IP addresses) to identify Pods
- You can control both ingress (incoming) and egress (outgoing) traffic
- A default-deny policy + explicit allows = secure by default
- Enforcement requires a compatible CNI plugin

**Next:** [Ingress — Exposing Services to the Outside World →](08-ingress-k8s.md)
