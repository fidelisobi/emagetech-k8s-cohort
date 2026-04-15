# Lab 28 — Policy Enforcement with Kyverno

## Overview

Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates resources using policies written in YAML. In this lab you will:

1. Install and verify Kyverno
2. Enforce **required labels** on all pods
3. Block pods that are missing **resource limits**
4. Block the use of the **`:latest` image tag**
5. Run test pods that intentionally pass and fail each policy

**Time estimate:** 40–50 minutes

---

## Prerequisites

- GKE cluster with kubectl configured
- Cluster-admin permissions (Kyverno needs to register admission webhooks)

### Install Kyverno

```bash
# Install via Helm (recommended for production)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --version 3.1.0

# Wait for Kyverno to be ready
kubectl wait --for=condition=Available deployment/kyverno \
  -n kyverno --timeout=120s
```

Verify:

```bash
kubectl get pods -n kyverno
# Expected: kyverno-admission-controller, kyverno-background-controller, etc. — all Running
```

---

## Setup — Create a Lab Namespace

```bash
kubectl create namespace policy-lab
```

---

## Policy 1 — Require Labels

### Apply the policy

```bash
kubectl apply -f 01-kyverno-require-labels.yaml
```

Verify the policy is active:

```bash
kubectl get clusterpolicy require-pod-labels
# READY should be True
```

### Test — should FAIL (no labels)

```bash
kubectl run no-labels-pod \
  --image=nginx:1.25.3 \
  -n policy-lab
```

Expected error:

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/policy-lab/no-labels-pod was blocked due to the following policies
require-pod-labels:
  check-required-labels: Pod is missing required labels. Add both 'app' and 'team' labels.
```

### Test — should PASS (correct labels)

```bash
kubectl run good-labels-pod \
  --image=nginx:1.25.3 \
  --labels="app=myapp,team=platform" \
  -n policy-lab
```

Verify it runs:

```bash
kubectl get pod good-labels-pod -n policy-lab
kubectl delete pod good-labels-pod -n policy-lab
```

---

## Policy 2 — Require Resource Limits

### Apply the policy

```bash
kubectl apply -f 02-kyverno-require-limits.yaml
```

### Test — should FAIL (no limits)

```bash
kubectl run no-limits-pod \
  --image=nginx:1.25.3 \
  --labels="app=test,team=lab" \
  -n policy-lab
# Expected: blocked by Kyverno
```

### Test — should PASS (with limits)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: with-limits-pod
  namespace: policy-lab
  labels:
    app: test
    team: lab
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
EOF
```

```bash
kubectl get pod with-limits-pod -n policy-lab
kubectl delete pod with-limits-pod -n policy-lab
```

---

## Policy 3 — Disallow :latest Tag

### Apply the policy

```bash
kubectl apply -f 03-kyverno-disallow-latest.yaml
```

### Test — should FAIL (:latest tag)

```bash
kubectl run latest-tag-pod \
  --image=nginx:latest \
  --labels="app=test,team=lab" \
  --overrides='{"spec":{"containers":[{"name":"latest-tag-pod","image":"nginx:latest","resources":{"limits":{"cpu":"100m","memory":"64Mi"}}}]}}' \
  -n policy-lab
# Expected: blocked
```

### Test — should FAIL (no tag)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-tag-pod
  namespace: policy-lab
  labels:
    app: test
    team: lab
spec:
  containers:
    - name: app
      image: nginx         # no tag = implicitly latest
      resources:
        limits:
          cpu: "100m"
          memory: "64Mi"
EOF
# Expected: blocked
```

### Test — should PASS (pinned version)

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pinned-version-pod
  namespace: policy-lab
  labels:
    app: test
    team: lab
spec:
  containers:
    - name: app
      image: nginx:1.25.3   # pinned version tag
      resources:
        limits:
          cpu: "100m"
          memory: "64Mi"
EOF
```

```bash
kubectl get pod pinned-version-pod -n policy-lab
kubectl delete pod pinned-version-pod -n policy-lab
```

---

## View Policy Reports

Kyverno generates PolicyReport objects for background scans of existing resources:

```bash
# View reports in the policy-lab namespace
kubectl get policyreport -n policy-lab

# View cluster-wide reports
kubectl get clusterpolicyreport

# Describe a report to see violations
kubectl describe policyreport -n policy-lab
```

---

## Switch to Audit Mode (non-blocking)

To observe violations without blocking deployments (useful during rollout):

```bash
kubectl patch clusterpolicy require-pod-labels \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/validationFailureAction","value":"Audit"}]'
```

Deploy a violating pod — it will succeed but a report entry is created:

```bash
kubectl run audit-test --image=nginx:1.25.3 -n policy-lab
kubectl get policyreport -n policy-lab
kubectl delete pod audit-test -n policy-lab
```

Switch back to Enforce:

```bash
kubectl patch clusterpolicy require-pod-labels \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/validationFailureAction","value":"Enforce"}]'
```

---

## Discussion Questions

1. What is the difference between `Enforce` and `Audit` mode?
2. Why should system namespaces be excluded from these policies?
3. How would you write a Kyverno policy that MUTATES resources (adds labels automatically)?
4. What is a `PolicyReport` and how does it help with compliance?

---

## Cleanup

```bash
kubectl delete namespace policy-lab
kubectl delete clusterpolicy require-pod-labels
kubectl delete clusterpolicy require-resource-limits
kubectl delete clusterpolicy disallow-latest-tag
```

---

## Key Concepts

| Concept | Description |
|---|---|
| `ClusterPolicy` | Kyverno policy that applies across all namespaces |
| `Policy` | Kyverno policy scoped to a single namespace |
| `validationFailureAction: Enforce` | Block requests that violate the policy |
| `validationFailureAction: Audit` | Allow but log violations (use during rollout) |
| `background: true` | Also scan existing resources and report violations |
| `pattern` | Simple key-value matching for validation |
| `deny.conditions` | Deny requests when conditions evaluate to true |
| `foreach` | Iterate over arrays (e.g. containers[]) in a resource |
| `PolicyReport` | Kyverno-generated report of policy violations per namespace |
