# Lab 17 — Kubernetes Network Policies

## Overview

Network Policies are the Kubernetes-native firewall for pod-to-pod traffic. In this lab you will:

1. Deploy a multi-tier app (frontend, backend, attacker) into an isolated namespace
2. Apply a **default-deny-all** policy and verify that all traffic is blocked
3. Selectively allow only frontend → backend traffic on port 8080
4. Restore DNS resolution with an egress allow rule
5. Confirm the attacker pod remains blocked

**Time estimate:** 30–40 minutes

---

## Prerequisites

- A running GKE cluster with kubectl configured
- `kubectl` version 1.24+
- GKE clusters have NetworkPolicy enforcement enabled by default (via Calico or Dataplane V2)

---

## Step 1 — Deploy the Lab Environment

```bash
kubectl apply -f 00-setup.yaml
```

Wait for all pods to be Running:

```bash
kubectl get pods -n netpol-lab -w
```

Expected output (all `Running`):

```
NAME                        READY   STATUS    RESTARTS   AGE
attacker-xxx                1/1     Running   0          30s
backend-xxx                 1/1     Running   0          30s
backend-xxx                 1/1     Running   0          30s
frontend-xxx                1/1     Running   0          30s
```

### Baseline connectivity test (should SUCCEED before any policy)

```bash
FRONTEND=$(kubectl get pod -n netpol-lab -l app=frontend -o name | head -1)
kubectl exec -n netpol-lab $FRONTEND -- curl -s --max-time 5 http://backend-svc:8080
```

You should see the nginx welcome page HTML.

---

## Step 2 — Apply Default Deny All

```bash
kubectl apply -f 01-default-deny-all.yaml
```

Verify the policy was created:

```bash
kubectl get networkpolicy -n netpol-lab
```

### Test — traffic should now be BLOCKED

```bash
kubectl exec -n netpol-lab $FRONTEND -- curl -s --max-time 3 http://backend-svc:8080
# Expected: curl: (28) Connection timed out (or similar)
echo "Exit code: $?"  # should be non-zero
```

> **What happened?** The default-deny policy selected all pods (`podSelector: {}`) and listed
> `Ingress` and `Egress` types with no rules — so ALL traffic is now blocked.

---

## Step 3 — Allow Frontend → Backend on Port 8080

```bash
kubectl apply -f 02-allow-frontend-to-backend.yaml
```

### Test 1 — frontend should now REACH backend

```bash
FRONTEND=$(kubectl get pod -n netpol-lab -l app=frontend -o name | head -1)
kubectl exec -n netpol-lab $FRONTEND -- curl -s --max-time 3 http://backend-svc:8080
```

> **Wait — did it still time out?** That is expected! The egress deny-all also blocks
> the frontend from making outbound connections. Continue to Step 4.

### Test 2 — attacker should STILL be blocked (do this after Step 4)

```bash
ATTACKER=$(kubectl get pod -n netpol-lab -l app=attacker -o name | head -1)
kubectl exec -n netpol-lab $ATTACKER -- curl -s --max-time 3 http://backend-svc:8080
# Expected: connection timed out
```

---

## Step 4 — Allow Egress DNS

```bash
kubectl apply -f 03-allow-egress-dns.yaml
```

### Test DNS resolution

```bash
FRONTEND=$(kubectl get pod -n netpol-lab -l app=frontend -o name | head -1)
kubectl exec -n netpol-lab $FRONTEND -- nslookup backend-svc
```

### Test full connectivity — frontend → backend should now SUCCEED

```bash
kubectl exec -n netpol-lab $FRONTEND -- curl -s --max-time 5 http://backend-svc:8080
# Expected: nginx welcome HTML
```

### Confirm attacker is still blocked

```bash
ATTACKER=$(kubectl get pod -n netpol-lab -l app=attacker -o name | head -1)
kubectl exec -n netpol-lab $ATTACKER -- curl -s --max-time 3 http://backend-svc:8080
# Expected: connection timed out — good!
```

---

## Step 5 — Inspect the Policies

List all network policies:

```bash
kubectl get networkpolicy -n netpol-lab
```

Describe a specific policy to see the full rule set:

```bash
kubectl describe networkpolicy allow-frontend-to-backend -n netpol-lab
```

---

## Discussion Questions

1. Why does an empty `podSelector: {}` select ALL pods instead of NO pods?
2. What would happen if you deleted the `default-deny-all` policy but kept the allow rules?
3. How would you allow the backend to make outbound calls to an external API?
4. What is the difference between a `namespaceSelector` and a `podSelector` in the `from` block?

---

## Cleanup

```bash
kubectl delete namespace netpol-lab
```

This deletes the namespace and all policies, deployments, and services inside it.

---

## Key Concepts

| Concept | Description |
|---|---|
| `podSelector: {}` | Matches ALL pods in the namespace |
| `policyTypes: [Ingress]` with no rules | Denies all inbound traffic |
| `policyTypes: [Egress]` with no rules | Denies all outbound traffic |
| `from.podSelector` | Allows traffic from pods matching the label |
| `from.namespaceSelector` | Allows traffic from pods in matching namespaces |
| Port-level control | Policies can restrict to specific ports and protocols |
