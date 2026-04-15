# Lab 27 — Istio Traffic Management

## Overview

Istio gives you fine-grained traffic control without changing application code. In this lab you will work with the Bookinfo sample app and:

1. Define **DestinationRule** subsets for three versions of the reviews service
2. Route 100% of traffic to **v1** to establish a stable baseline
3. Implement a **canary** rollout with 80/20 traffic split
4. Enable **STRICT mTLS** across the bookinfo namespace
5. Inject a **5-second delay fault** to test application resiliency

**Time estimate:** 45–60 minutes

---

## Prerequisites

- Istio installed on the GKE cluster (`kubectl get pods -n istio-system`)
- Bookinfo app running in the `bookinfo` namespace
- `istioctl` CLI installed locally

### Verify Bookinfo is deployed

```bash
kubectl get pods -n bookinfo
# All pods should be Running with 2/2 containers (app + Envoy sidecar)
```

### Open Bookinfo in a browser

```bash
GATEWAY_URL=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://$GATEWAY_URL/productpage"
```

Open the URL and refresh several times — notice the reviews section changes randomly between no stars, black stars, and red stars. After this lab, you will control that behavior.

---

## Step 1 — Define DestinationRule Subsets

```bash
kubectl apply -f 01-destination-rule.yaml
```

Verify:

```bash
kubectl get destinationrule -n bookinfo
kubectl describe destinationrule reviews-destination-rule -n bookinfo
```

---

## Step 2 — Route All Traffic to v1

```bash
kubectl apply -f 02-virtualservice-v1-only.yaml
```

Test — refresh the Bookinfo page 10 times:

```bash
# From inside the cluster:
for i in $(seq 1 10); do
  kubectl exec -n bookinfo deploy/ratings-v1 -- \
    curl -s http://reviews:9080/reviews/1 | grep -c '"color"'
done
# Every response should return 0 (v1 has no star ratings)
```

The browser should now consistently show **no stars** (v1).

---

## Step 3 — Canary: 80/20 Split

```bash
kubectl apply -f 03-virtualservice-canary.yaml
```

Generate traffic and count responses:

```bash
V1=0; V2=0
for i in $(seq 1 40); do
  RESP=$(kubectl exec -n bookinfo deploy/ratings-v1 -- \
    curl -s http://reviews:9080/reviews/1)
  if echo "$RESP" | grep -q '"color":"black"'; then
    V2=$((V2+1))
  else
    V1=$((V1+1))
  fi
done
echo "v1 (no stars): $V1 / 40"
echo "v2 (black stars): $V2 / 40"
# Expect approximately v1=32, v2=8
```

### Test the header override

```bash
# Requests with this header always go to v2
kubectl exec -n bookinfo deploy/ratings-v1 -- \
  curl -s -H "end-user: canary-tester" http://reviews:9080/reviews/1 | \
  grep -o '"color":"[^"]*"'
# Expected: "color":"black"  (v2)
```

---

## Step 4 — Enable STRICT mTLS

```bash
kubectl apply -f 04-peer-authentication.yaml
```

Verify mTLS is active:

```bash
kubectl get peerauthentication -n bookinfo

# Describe a pod to see its mTLS status
istioctl x describe pod \
  $(kubectl get pod -n bookinfo -l app=productpage -o name | head -1 | sed 's|pod/||') \
  -n bookinfo
```

Verify that traffic between services is now encrypted:

```bash
istioctl proxy-config cluster \
  $(kubectl get pod -n bookinfo -l app=productpage -o name | head -1 | sed 's|pod/||') \
  -n bookinfo | grep reviews
# Should show TLS mode: ISTIO_MUTUAL
```

Confirm a non-sidecar pod is rejected:

```bash
# Launch a pod without a sidecar
kubectl run no-sidecar-test \
  --image=curlimages/curl \
  --restart=Never \
  --labels="sidecar.istio.io/inject=false" \
  -- sleep 600

kubectl exec no-sidecar-test -- \
  curl -s --max-time 3 http://productpage.bookinfo:9080/productpage
# Expected: connection refused or SSL handshake error

kubectl delete pod no-sidecar-test
```

---

## Step 5 — Fault Injection

```bash
kubectl apply -f 05-fault-injection.yaml
```

Observe latency in the browser — about half the page loads will take 5+ seconds.

Measure the delay programmatically:

```bash
for i in $(seq 1 10); do
  time kubectl exec -n bookinfo deploy/productpage-v1 -- \
    curl -s http://ratings:9080/ratings/1 > /dev/null
done
# About 5 of the 10 runs should take ~5 seconds
```

### Remove the fault injection

```bash
# Re-apply v1-only routing (which has no fault block)
kubectl apply -f 02-virtualservice-v1-only.yaml
# Also delete the ratings VirtualService from step 5
kubectl delete virtualservice ratings -n bookinfo
```

---

## Discussion Questions

1. What is the difference between a VirtualService and a DestinationRule?
2. Why must weights in an HTTP route sum to 100?
3. What does STRICT mTLS mean for pods without Istio sidecars?
4. How would you use fault injection in a CI pipeline?

---

## Cleanup

```bash
kubectl delete virtualservice reviews -n bookinfo
kubectl delete virtualservice ratings -n bookinfo
kubectl delete destinationrule reviews-destination-rule -n bookinfo
kubectl delete destinationrule ratings-destination-rule -n bookinfo
kubectl delete peerauthentication bookinfo-strict-mtls -n bookinfo
```

---

## Key Concepts

| Resource | Purpose |
|---|---|
| `DestinationRule` | Defines named subsets + traffic policies (LB, circuit breaker) for a service |
| `VirtualService` | Defines routing rules: where to send requests and in what proportion |
| `weight` | Percentage of traffic to a destination (all weights in a route must sum to 100) |
| `PeerAuthentication` | Configures mTLS mode (PERMISSIVE or STRICT) for a namespace |
| `fault.delay` | Injects artificial latency into a percentage of requests |
| `fault.abort` | Returns HTTP error codes for a percentage of requests |
| Canary pattern | Gradually shift traffic from stable to new version using weight |
