# Lab 15 — ConfigMaps, Secrets, and the Downward API

## Overview

In this lab you will learn how to separate configuration from container images using ConfigMaps and Secrets, and how to expose pod metadata to applications via the Downward API. You will:

1. Create a ConfigMap with flat key-value pairs and a multi-line file entry
2. Create a Secret using `stringData` and inspect its base64-encoded form
3. Deploy a pod that consumes ConfigMap and Secret values as environment variables (both `envFrom` bulk import and `valueFrom` selective import)
4. Deploy a pod that mounts ConfigMap and Secret as files, and uses the Downward API
5. Observe the live-update behavior of volume-mounted files vs. environment variables

**Time estimate:** 35–45 minutes

---

## Prerequisites

- A running GKE cluster with `kubectl` configured
- No special add-ons required for this lab

---

## Step 1 — Create the Namespace

All lab resources live in a dedicated namespace so cleanup is a single command.

```bash
kubectl create namespace cm-secrets-lab
```

Verify it exists:

```bash
kubectl get namespace cm-secrets-lab
```

---

## Step 2 — Create the ConfigMap

```bash
kubectl apply -f 01-configmap.yaml
```

Inspect the ConfigMap:

```bash
kubectl get configmap app-config -n cm-secrets-lab
kubectl describe configmap app-config -n cm-secrets-lab
```

Notice that the `app.properties` key contains multi-line content — Kubernetes stores it verbatim.

---

## Step 3 — Create the Secret

```bash
kubectl apply -f 02-secret.yaml
```

### stringData vs data

The YAML uses `stringData` (plain text). Now retrieve the stored secret to see what Kubernetes actually saves:

```bash
kubectl get secret app-secret -n cm-secrets-lab -o yaml
```

Expected output (abbreviated):

```yaml
apiVersion: v1
data:
  DB_PASSWORD: czNjcjN0UEBzc3cwcmQh   # base64-encoded
  DB_URL: cG9zdGdyZXNxbDovL2xhYnVzZXI6czNjcjN0UEBzc3cwcmQhQH...
  DB_USER: bGFidXNlcg==
kind: Secret
...
```

Decode a value to confirm:

```bash
kubectl get secret app-secret -n cm-secrets-lab \
  -o jsonpath='{.data.DB_USER}' | base64 --decode
# Expected: labuser
```

> **Key insight:** `stringData` is a write-only convenience field. On retrieval Kubernetes always returns the `data` block with base64-encoded values. This is encoding, NOT encryption.

---

## Step 4 — Deploy the Environment Variable Injection Pod

```bash
kubectl apply -f 03-pod-env-injection.yaml
```

Wait for the pod to be Running:

```bash
kubectl get pod env-injection-pod -n cm-secrets-lab -w
```

Exec in and verify environment variables:

```bash
kubectl exec -it env-injection-pod -n cm-secrets-lab -- sh
```

Inside the container, run:

```sh
# Verify bulk-imported ConfigMap values (via envFrom)
echo "LOG_LEVEL=$LOG_LEVEL"
echo "DB_HOST=$DB_HOST"
echo "APP_ENV=$APP_ENV"

# Verify bulk-imported Secret values (via envFrom)
echo "DB_USER=$DB_USER"
echo "DB_PASSWORD=$DB_PASSWORD"

# Verify selectively imported and renamed values (via valueFrom)
echo "LOGGING_LEVEL=$LOGGING_LEVEL"
echo "DATABASE_PASSWORD=$DATABASE_PASSWORD"

# Print all env vars
env | sort

exit
```

Expected output includes all ConfigMap keys (`LOG_LEVEL=info`, `DB_HOST=postgres...`, etc.) and all Secret keys as plain text (they are decoded in memory by the kubelet).

---

## Step 5 — Deploy the Volume Mount Pod

```bash
kubectl apply -f 04-pod-volume-mount.yaml
```

Wait for Running:

```bash
kubectl get pod volume-mount-pod -n cm-secrets-lab -w
```

Exec in and explore the mounted files:

```bash
kubectl exec -it volume-mount-pod -n cm-secrets-lab -- sh
```

Inside the container:

```sh
# --- ConfigMap files ---
ls /etc/config/
# Expected: LOG_LEVEL  DB_HOST  DB_PORT  APP_ENV  app.properties

cat /etc/config/LOG_LEVEL
# Expected: info

cat /etc/config/app.properties
# Expected: the multi-line properties content

# --- Secret files ---
ls /etc/secret/
# Expected: DB_USER  DB_PASSWORD  DB_URL

cat /etc/secret/DB_USER
# Expected: labuser  (plain text — kubelet decodes from base64)

# Check file permissions (should be 0400)
ls -la /etc/secret/

# --- Downward API files ---
ls /etc/podinfo/
# Expected: pod-name  namespace  labels  annotations  mem-limit

cat /etc/podinfo/pod-name
# Expected: volume-mount-pod

cat /etc/podinfo/namespace
# Expected: cm-secrets-lab

cat /etc/podinfo/labels
# Expected: key=value pairs for all pod labels

cat /etc/podinfo/mem-limit
# Expected: 67108864  (64Mi in bytes)

exit
```

---

## Step 6 — Observe Live Updates for Volume-Mounted Files

This step demonstrates that volume-mounted ConfigMap files update automatically when the ConfigMap changes, but environment variables do not.

### 6a. Update the ConfigMap

```bash
kubectl patch configmap app-config -n cm-secrets-lab \
  --type merge \
  -p '{"data":{"LOG_LEVEL":"debug"}}'
```

Verify the ConfigMap was updated:

```bash
kubectl get configmap app-config -n cm-secrets-lab \
  -o jsonpath='{.data.LOG_LEVEL}'
# Expected: debug
```

### 6b. Check the volume-mounted file (will update within ~60s)

```bash
kubectl exec volume-mount-pod -n cm-secrets-lab -- cat /etc/config/LOG_LEVEL
```

Wait up to 60 seconds for the kubelet sync cycle and run again:

```bash
# Keep running this until you see "debug"
kubectl exec volume-mount-pod -n cm-secrets-lab -- cat /etc/config/LOG_LEVEL
```

### 6c. Check the environment variable (will NOT update)

```bash
kubectl exec env-injection-pod -n cm-secrets-lab -- sh -c 'echo $LOG_LEVEL'
# Expected: info  (still the OLD value — env vars are set at start time)
```

> **Key takeaway:** Volume-mounted files reflect ConfigMap/Secret changes within the kubelet sync interval (default ~60s). Environment variables are immutable for the lifetime of the pod — you must restart the pod to pick up changes.

---

## Step 7 — Discussion Questions

1. What is the difference between `envFrom` and `valueFrom` for environment injection?
2. Why are volume-mounted files updated but environment variables are not?
3. What happens to the pod if a referenced ConfigMap or Secret does not exist (and `optional: true` is not set)?
4. When would you use the Downward API instead of hardcoding values in a ConfigMap?
5. How does GKE's KMS envelope encryption improve on the default base64 storage?

---

## Cleanup

```bash
kubectl delete namespace cm-secrets-lab
```

---

## Key Concepts

| Concept | Description |
|---|---|
| `configMapRef` (envFrom) | Bulk import all ConfigMap keys as env vars |
| `secretRef` (envFrom) | Bulk import all Secret keys as env vars |
| `configMapKeyRef` (valueFrom) | Import a single ConfigMap key, optionally renamed |
| `secretKeyRef` (valueFrom) | Import a single Secret key, optionally renamed |
| ConfigMap volume | Each key becomes a file; updates propagate automatically |
| Secret volume | Same as ConfigMap but with stricter default permissions (0400) |
| Downward API | Expose pod metadata (name, namespace, labels) as env vars or files |
| `stringData` | Write-only convenience field; stored as base64 in `data` |
