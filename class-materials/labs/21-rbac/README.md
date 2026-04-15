# Lab 21 — RBAC and Resource Quotas

## Overview

Kubernetes Role-Based Access Control (RBAC) controls which users and workloads can perform which actions on which resources. ResourceQuotas enforce consumption limits per namespace. In this lab you will:

1. Create a namespace, ServiceAccount, Role, and RoleBinding
2. Deploy a test pod that runs as the ServiceAccount
3. Exec into the pod and test allowed vs. denied API operations
4. Apply a ResourceQuota and observe how it constrains pod creation
5. Use `kubectl auth can-i` to check permissions without exec-ing into a pod

**Time estimate:** 40–50 minutes

---

## Prerequisites

- A running GKE cluster with `kubectl` configured
- Cluster-admin permissions (to create Roles and RoleBindings)

---

## Step 1 — Create the Namespace

```bash
kubectl create namespace rbac-lab
```

---

## Step 2 — Apply the RBAC Resources

Apply all RBAC objects in order:

```bash
kubectl apply -f 01-serviceaccount.yaml
kubectl apply -f 02-role.yaml
kubectl apply -f 03-rolebinding.yaml
```

Verify each was created:

```bash
kubectl get serviceaccount dev-user -n rbac-lab
kubectl get role pod-reader -n rbac-lab
kubectl get rolebinding dev-user-pod-reader -n rbac-lab
```

Describe the Role to see the permission rules:

```bash
kubectl describe role pod-reader -n rbac-lab
```

---

## Step 3 — Deploy the Test Pod

```bash
kubectl apply -f 04-test-pod.yaml
```

Wait for it to be Running:

```bash
kubectl get pod rbac-test-pod -n rbac-lab -w
```

---

## Step 4 — Test RBAC Permissions from Inside the Pod

Exec into the test pod:

```bash
kubectl exec -it rbac-test-pod -n rbac-lab -- sh
```

Inside the container, run the following commands and observe the results:

### Allowed operations (should succeed):

```sh
# List pods in the rbac-lab namespace
kubectl get pods -n rbac-lab
# Expected: lists pods including rbac-test-pod

# Get a specific pod
kubectl get pod rbac-test-pod -n rbac-lab
# Expected: shows pod details

# List services
kubectl get services -n rbac-lab
# Expected: lists services (kubernetes service is in default ns, so likely empty)

# Check your own identity
kubectl auth whoami
# Expected: shows dev-user ServiceAccount
```

### Denied operations (should fail with "Forbidden"):

```sh
# Try to create a deployment (not in the Role)
kubectl create deployment test-deploy --image=nginx -n rbac-lab
# Expected: Error from server (Forbidden): ...

# Try to list secrets (not in the Role)
kubectl get secrets -n rbac-lab
# Expected: Error from server (Forbidden): ...

# Try to delete a pod (delete verb not granted)
kubectl delete pod rbac-test-pod -n rbac-lab
# Expected: Error from server (Forbidden): ...

# Try to access a different namespace (Role is namespace-scoped)
kubectl get pods -n default
# Expected: Error from server (Forbidden): ...

exit
```

> **Key insight:** RBAC is additive — there are no deny rules. Any action not explicitly granted is implicitly denied.

---

## Step 5 — Check Permissions with `kubectl auth can-i`

From your local terminal (with cluster-admin), check what the `dev-user` ServiceAccount can do without exec-ing into a pod:

```bash
# Can dev-user list pods in rbac-lab? (should be yes)
kubectl auth can-i list pods \
  --namespace rbac-lab \
  --as system:serviceaccount:rbac-lab:dev-user

# Can dev-user create deployments? (should be no)
kubectl auth can-i create deployments \
  --namespace rbac-lab \
  --as system:serviceaccount:rbac-lab:dev-user

# Can dev-user get secrets? (should be no)
kubectl auth can-i get secrets \
  --namespace rbac-lab \
  --as system:serviceaccount:rbac-lab:dev-user

# Can dev-user list pods in the default namespace? (should be no)
kubectl auth can-i list pods \
  --namespace default \
  --as system:serviceaccount:rbac-lab:dev-user
```

List all permissions for the ServiceAccount:

```bash
kubectl auth can-i --list \
  --namespace rbac-lab \
  --as system:serviceaccount:rbac-lab:dev-user
```

---

## Step 6 — Apply the ResourceQuota

```bash
kubectl apply -f 05-resourcequota.yaml
```

View the quota and current usage:

```bash
kubectl describe resourcequota rbac-lab-quota -n rbac-lab
```

Expected output (usage reflects rbac-test-pod):

```
Name:            rbac-lab-quota
Namespace:       rbac-lab
Resource         Used    Hard
--------         ----    ----
configmaps       0       5
limits.cpu       100m    1000m
limits.memory    128Mi   512Mi
pods             1       5
requests.cpu     50m     500m
requests.memory  64Mi    256Mi
requests.storage 0       2Gi
secrets          1       10
services         0       3
```

### Test: Create a pod that fits within quota

```bash
kubectl run quota-test-1 -n rbac-lab \
  --image=busybox:1.36 \
  --restart=Never \
  --requests='cpu=50m,memory=32Mi' \
  --limits='cpu=100m,memory=64Mi' \
  -- sleep 300
```

### Test: Exceed the pod count quota

Create more pods to approach the limit of 5:

```bash
for i in 2 3 4 5 6; do
  kubectl run quota-test-${i} -n rbac-lab \
    --image=busybox:1.36 \
    --restart=Never \
    --requests='cpu=10m,memory=8Mi' \
    --limits='cpu=20m,memory=16Mi' \
    -- sleep 300 2>&1 | head -3
done
```

The 6th pod (quota-test-6) should be rejected:

```
Error from server (Forbidden): pods "quota-test-6" is forbidden:
exceeded quota: rbac-lab-quota, requested: pods=1, used: pods=5, limited: pods=5
```

### Test: Create a pod without resource requests (should be rejected)

After a ResourceQuota sets cpu/memory limits, pods MUST specify resource requests:

```bash
kubectl run no-resources -n rbac-lab \
  --image=busybox:1.36 \
  --restart=Never \
  -- sleep 300
# Expected: Forbidden — must specify cpu/memory requests when quota is active
```

---

## Step 7 — Discussion Questions

1. What is the difference between a `Role` and a `ClusterRole`?
2. What is the difference between a `RoleBinding` and a `ClusterRoleBinding`?
3. Can you bind a `ClusterRole` with a `RoleBinding`? What effect does that have?
4. Why does Kubernetes RBAC have no deny rules? What are the security implications?
5. What happens when a ResourceQuota is applied to a namespace that already has pods without resource requests?

---

## Cleanup

```bash
kubectl delete namespace rbac-lab
```

---

## Key Concepts

| Concept | Scope | Description |
|---|---|---|
| ServiceAccount | Namespace | Pod identity for API authentication |
| Role | Namespace | Set of permissions within one namespace |
| ClusterRole | Cluster | Set of permissions cluster-wide or for non-namespaced resources |
| RoleBinding | Namespace | Grants a Role/ClusterRole to subjects in one namespace |
| ClusterRoleBinding | Cluster | Grants a ClusterRole to subjects cluster-wide |
| ResourceQuota | Namespace | Hard limits on resource consumption per namespace |
| `kubectl auth can-i` | — | Check permissions for a subject without exec |
