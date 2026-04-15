# Lab 13: Labels, Selectors, and CRDs

## Overview

Labels are the connective tissue of Kubernetes — Services, ReplicaSets, NetworkPolicies,
and many other objects use label selectors to find the pods they manage. In this lab you
will practice every form of label selector, then extend the Kubernetes API itself by
creating a Custom Resource Definition (CRD).

**Estimated time:** 40 minutes

**Prerequisites:**
- Completed Lab 11 (cluster connection working)
- `kubectl` pointing at the shared GKE cluster
- Cluster-admin or equivalent RBAC permissions (needed to create CRDs)

---

## Part 1: Deploy the Label Exercise Pods

```bash
# Apply all four pods from the manifest
kubectl apply -f 01-labels-exercise.yaml
```

Expected output:
```
pod/pod-frontend-prod created
pod/pod-backend-prod created
pod/pod-frontend-staging created
pod/pod-cache-staging created
```

```bash
# Verify all four are Running and inspect their labels
kubectl get pods --show-labels
```

Your four pods have these label combinations:

| Pod | app | env | tier |
|---|---|---|---|
| pod-frontend-prod | web-server | production | frontend |
| pod-backend-prod | api-server | production | backend |
| pod-frontend-staging | web-server | staging | frontend |
| pod-cache-staging | redis | staging | cache |

---

## Part 2: Equality-Based Selectors

Equality selectors use `=`, `==` (same meaning), or `!=` operators.

```bash
# Select pods where env equals production (returns 2 pods)
kubectl get pods -l env=production

# Select pods where tier equals frontend (returns 2 pods)
kubectl get pods -l tier=frontend

# Select pods where app equals web-server (returns 2 pods)
kubectl get pods -l app=web-server

# Combine multiple equality conditions with a comma (AND logic)
# Returns pods that are BOTH frontend AND in production (returns 1 pod)
kubectl get pods -l tier=frontend,env=production

# Select pods where env is NOT production (returns 2 pods)
kubectl get pods -l env!=production

# Select pods with a specific app in staging
kubectl get pods -l app=redis,env=staging
```

> **Question:** What is the difference between `-l env=production,tier=frontend`
> (comma-separated) and running two separate `get` commands? Which is AND logic and
> which is OR logic?

---

## Part 3: Set-Based Selectors

Set-based selectors use `in`, `notin`, and `exists` operators. They are more expressive
than equality selectors.

```bash
# "in" — select pods whose env label is one of the listed values
# Returns all 4 pods (both production and staging)
kubectl get pods -l 'env in (production, staging)'

# Returns only production pods (same as env=production)
kubectl get pods -l 'env in (production)'

# "notin" — select pods whose tier is NOT in the listed values
# Returns backend and cache pods (excludes frontend)
kubectl get pods -l 'tier notin (frontend)'

# "exists" — select pods that HAVE the label key at all (any value)
# Returns all 4 pods because all have the "tier" label
kubectl get pods -l 'tier'

# Combine set-based and equality selectors (they can be mixed)
kubectl get pods -l 'env in (staging), tier notin (cache)'
```

> **Note:** Set-based selectors that contain spaces or special characters must be
> quoted on the command line (single quotes work well in bash).

---

## Part 4: Label Selector with --show-labels and -o wide

```bash
# --show-labels appends a LABELS column to the default output
kubectl get pods --show-labels

# Combine -l with --show-labels to confirm your filter is working
kubectl get pods -l env=production --show-labels

# -o wide adds NODE and IP columns — useful to see where selected pods landed
kubectl get pods -l tier=frontend -o wide

# Count how many pods match a selector
kubectl get pods -l lab=13-api-objects --no-headers | wc -l
```

---

## Part 5: Imperative Label Management

```bash
# Add a new label to a running pod
kubectl label pod pod-frontend-prod version=v2

# Verify the new label appears
kubectl get pod pod-frontend-prod --show-labels

# Overwrite an existing label (--overwrite is required to change an existing key)
kubectl label pod pod-frontend-prod env=prod-v2 --overwrite

# Remove a label by appending a minus sign (-) to the key
kubectl label pod pod-frontend-prod env-

# Verify the label was removed
kubectl get pod pod-frontend-prod --show-labels

# Add the same label to multiple pods in one command
kubectl label pods pod-frontend-staging pod-cache-staging release=alpha
kubectl get pods --show-labels
```

---

## Part 6: Annotations

Annotations hold non-identifying metadata. They are NOT used for selection but are
commonly read by operators, monitoring tools, and CI/CD pipelines.

```bash
# Add an annotation to a pod
kubectl annotate pod pod-frontend-prod \
  deployment-tool="kubectl" \
  last-deployed-by="training-team"

# View annotations
kubectl describe pod pod-frontend-prod | grep -A 10 "Annotations:"

# Overwrite an annotation
kubectl annotate pod pod-frontend-prod last-deployed-by="lab-student" --overwrite

# Remove an annotation (same minus-sign pattern as labels)
kubectl annotate pod pod-frontend-prod deployment-tool-
```

> **Key difference:** Labels are for selection (Services, ReplicaSets, and NetworkPolicies
> use them to find pods). Annotations are for storing metadata that tools and humans read
> but that Kubernetes itself does not act on for scheduling or routing decisions.

---

## Part 7: Create the CRD and a Custom Resource Instance

### 7.1 Understand what you are about to do

`02-crd-example.yaml` contains two Kubernetes objects:
1. A **CustomResourceDefinition** that registers a new API type called `Greeting`
2. A **Greeting instance** — the first object of our new type

### 7.2 Apply the CRD

```bash
# Apply the whole file — kubectl processes the objects in order
kubectl apply -f 02-crd-example.yaml
```

Expected output:
```
customresourcedefinition.apiextensions.k8s.io/greetings.training.example.com created
greeting.training.example.com/hello-world created
```

### 7.3 Verify the CRD was registered

```bash
# List all CRDs in the cluster
kubectl get crds

# Find your specific CRD
kubectl get crd greetings.training.example.com

# Read the full CRD definition
kubectl describe crd greetings.training.example.com
```

### 7.4 Interact with your new resource type

```bash
# List all Greeting objects (notice the custom columns from additionalPrinterColumns)
kubectl get greetings

# Shorthand works too — we defined "gt" as a shortName in the CRD
kubectl get gt

# Get full YAML of the instance
kubectl get greeting hello-world -o yaml

# Describe it
kubectl describe greeting hello-world
```

---

## Part 8: Create Additional Greeting Instances

```bash
# Create a second greeting imperatively using kubectl create
# (This uses the --dry-run=client trick to generate a manifest, then pipes it to apply)
kubectl apply -f - <<EOF
apiVersion: training.example.com/v1
kind: Greeting
metadata:
  name: hola-mundo
  namespace: default
  labels:
    lab: "13-api-objects"
spec:
  message: "Hola, Kubernetes!"
  language: spanish
  recipient: "Estudiantes"
EOF
```

```bash
# Try to create an invalid Greeting (language "klingon" is not in the enum)
# This should be REJECTED by the API server
kubectl apply -f - <<EOF
apiVersion: training.example.com/v1
kind: Greeting
metadata:
  name: invalid-greeting
  namespace: default
spec:
  message: "Qapla'!"
  language: klingon
EOF
```

Expected error:
```
The Greeting "invalid-greeting" is invalid: spec.language: Unsupported value: "klingon"
```

This demonstrates that CRD schemas provide real validation at admission time.

```bash
# List all greetings now — should show both hello-world and hola-mundo
kubectl get greetings --show-labels
```

---

## Part 9: Discover Resources with kubectl api-resources and explain

### 9.1 Find your new resource type in the API

```bash
# After applying the CRD, your new type appears in the API resource list
kubectl api-resources | grep training

# You should see:
# greetings   gt   training.example.com/v1   true   Greeting
```

### 9.2 Use kubectl explain on a CRD type

`kubectl explain` works on custom resources too — it reads the openAPIV3Schema from the
CRD spec:

```bash
# Top-level documentation
kubectl explain greeting

# Dive into the spec fields
kubectl explain greeting.spec

# Read the message field documentation
kubectl explain greeting.spec.message
```

### 9.3 Check API versions and groups

```bash
# Your new API group should appear in the list
kubectl api-versions | grep training

# Browse all API groups
kubectl api-versions | sort
```

---

## Part 10: Label Selectors on Custom Resources

Labels and selectors work on custom resources exactly as they do on Pods:

```bash
# Select greetings by label
kubectl get greetings -l lab=13-api-objects

# Select greetings in spanish (this uses a label, not a spec field)
# First, add a language label to make selection easier
kubectl label greeting hola-mundo language=spanish
kubectl label greeting hello-world language=english

# Now select by the label
kubectl get greetings -l language=spanish --show-labels
```

---

## Clean Up

```bash
# Delete the Greeting instances first
kubectl delete greeting hello-world
kubectl delete greeting hola-mundo

# Delete the label exercise pods
kubectl delete -f 01-labels-exercise.yaml

# Delete the CRD (this also deletes all Greeting instances in ALL namespaces)
kubectl delete crd greetings.training.example.com

# Verify cleanup
kubectl get pods -l lab=13-api-objects
kubectl get greetings 2>&1 | head -5   # Should say "No resources found" or CRD not found
```

---

## Summary

After completing this lab you should be able to:

- Use equality-based selectors (`=`, `!=`) to filter pods with `-l`
- Use set-based selectors (`in`, `notin`, `exists`) for more expressive filtering
- Add, overwrite, and remove labels and annotations imperatively
- Explain the difference between labels (for selection) and annotations (for metadata)
- Create a CRD that registers a new namespaced API type with schema validation
- Create, list, describe, and delete custom resource instances
- Use `kubectl api-resources` to discover custom types registered in the cluster
- Use `kubectl explain` to read inline documentation for custom resource fields
