# Lab 18 — Kubernetes Gateway API

## Overview

The Gateway API is the future of Kubernetes ingress. In this lab you will:

1. Create a **GatewayClass** and **Gateway** backed by Istio
2. Route HTTP traffic to different backends based on URL path
3. Implement a **canary deployment** using weighted traffic splitting

**Time estimate:** 35–45 minutes

---

## Prerequisites

- Istio installed on the cluster (`kubectl get pods -n istio-system`)
- Gateway API CRDs installed (`kubectl get crd gateways.gateway.networking.k8s.io`)
- A running GKE cluster with kubectl configured

### Check prerequisites

```bash
# Verify Istio is running
kubectl get pods -n istio-system

# Verify Gateway API CRDs exist
kubectl get crd | grep gateway.networking.k8s.io
```

If Gateway API CRDs are missing:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

---

## Step 1 — Create the GatewayClass and Gateway

```bash
kubectl apply -f 01-gateway.yaml
```

Verify the Gateway is accepted by the controller:

```bash
kubectl get gatewayclass istio
kubectl get gateway shared-gateway -n gateway-lab
```

Wait for the Gateway to get an external IP (this provisions a LoadBalancer):

```bash
kubectl get gateway shared-gateway -n gateway-lab -w
# Wait until PROGRAMMED = True and ADDRESS is populated
```

Save the IP for later tests:

```bash
export GW_IP=$(kubectl get gateway shared-gateway -n gateway-lab \
  -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: $GW_IP"
```

---

## Step 2 — Apply Path-based Routing

```bash
kubectl apply -f 02-httproute-basic.yaml
```

Verify the HTTPRoute is accepted:

```bash
kubectl get httproute path-based-route -n gateway-lab
# STATUS column should show "Accepted"
```

### Test path routing

```bash
# Should reach the API backend
curl -H "Host: lab.example.com" http://$GW_IP/api/health
# Expected: Hello from the API backend

# Should reach the frontend
curl -H "Host: lab.example.com" http://$GW_IP/web/index.html
# Expected: Hello from the Frontend
```

> The `-H "Host: lab.example.com"` header is needed because the HTTPRoute
> filters on hostname. In a real setup you would point a DNS record at `$GW_IP`.

---

## Step 3 — Traffic Splitting (Canary)

```bash
kubectl apply -f 03-httproute-traffic-split.yaml
```

### Watch the 90/10 split in action

```bash
for i in $(seq 1 20); do
  curl -s -H "Host: lab.example.com" http://$GW_IP/app
  echo
done
# Approximately 18 responses → "v1 — stable release"
# Approximately  2 responses → "v2 — canary release"
```

### Shift to 50/50 (edit the route live)

```bash
kubectl patch httproute canary-route -n gateway-lab --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/rules/0/backendRefs/0/weight", "value": 5},
    {"op": "replace", "path": "/spec/rules/0/backendRefs/1/weight", "value": 5}
  ]'
```

Re-run the loop and observe the change in distribution.

### Fully promote the canary to 100%

```bash
kubectl patch httproute canary-route -n gateway-lab --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/rules/0/backendRefs/0/weight", "value": 0},
    {"op": "replace", "path": "/spec/rules/0/backendRefs/1/weight", "value": 10}
  ]'
```

---

## Discussion Questions

1. What is the role separation between GatewayClass, Gateway, and HTTPRoute?
2. How does Gateway API compare to the legacy Ingress resource?
3. Can two HTTPRoutes in different namespaces attach to the same Gateway?
4. What happens if the sum of `weight` values equals zero?

---

## Cleanup

```bash
kubectl delete namespace gateway-lab
kubectl delete gatewayclass istio
```

---

## Key Concepts

| Resource | Scope | Owner | Purpose |
|---|---|---|---|
| `GatewayClass` | Cluster | Infra team | Identifies the controller implementation |
| `Gateway` | Namespace | Infra/Platform team | Defines listeners (ports, TLS, allowed routes) |
| `HTTPRoute` | Namespace | App team | Defines routing rules to backend services |
| `weight` | Per backendRef | App team | Controls traffic split percentage |
| `PathPrefix` match | Rule | App team | Routes by URL path prefix |
