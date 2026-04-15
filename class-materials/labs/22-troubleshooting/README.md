# Lab 22 — Troubleshooting Scenarios

## Overview

Debugging broken Kubernetes workloads is a core operational skill. In this lab you will encounter four realistic failure scenarios, diagnose each one using `kubectl describe`, `logs`, and `events`, identify the root cause, and apply a fix. You will also practice `kubectl debug` for containers without shells.

The four scenarios:

| File | Symptom | Root Cause |
|---|---|---|
| `01-crashloop-pod.yaml` | CrashLoopBackOff | Bad command — binary does not exist |
| `02-imagepull-pod.yaml` | ImagePullBackOff | Non-existent image tag |
| `03-pending-pod.yaml` | Pending (never starts) | CPU request exceeds all node capacity |
| `04-misconfigured-service.yaml` | Service has no endpoints | Service selector does not match pod labels |

**Time estimate:** 50–60 minutes

---

## Prerequisites

- A running GKE cluster with `kubectl` configured
- Approach each scenario as a detective exercise — diagnose before reading the root cause

---

## Setup

Create the namespace once for all scenarios:

```bash
kubectl create namespace troubleshoot-lab
```

**Work through one scenario at a time. Clean up between scenarios.**

---

## Scenario 1 — CrashLoopBackOff

### Deploy

```bash
kubectl apply -f 01-crashloop-pod.yaml
```

### Observe the symptom

```bash
kubectl get pod crashloop-pod -n troubleshoot-lab -w
```

Watch the STATUS column cycle through: `ContainerCreating → Error → CrashLoopBackOff`

After a few restarts, stop watching (Ctrl-C) and describe the pod:

```bash
kubectl describe pod crashloop-pod -n troubleshoot-lab
```

Look at:
- `State:` — shows `Waiting`, reason `CrashLoopBackOff`
- `Last State:` — shows the previous run, exit code, and reason
- `Events:` — shows `Back-off restarting failed container`

### Get the logs

```bash
# Current run (may be empty if it crashed before writing output)
kubectl logs crashloop-pod -n troubleshoot-lab

# Previous run — CRITICAL for CrashLoopBackOff diagnosis
kubectl logs crashloop-pod -n troubleshoot-lab --previous
```

The `--previous` flag retrieves logs from the LAST terminated container instance. You should see an error like:

```
exec /bin/launch-app: no such file or directory
```

### Root cause

The container's `command` specifies `/bin/launch-app`, which does not exist in the `busybox:1.36` image.

### Fix

Edit the YAML and change the command to a valid binary:

```bash
kubectl patch pod crashloop-pod -n troubleshoot-lab \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/containers/0/command", "value": ["sleep", "3600"]}]'
```

> Note: Pod specs are largely immutable after creation. In practice you would edit the Deployment and roll out a new ReplicaSet. For this lab, delete and recreate the pod:

```bash
kubectl delete pod crashloop-pod -n troubleshoot-lab

# Edit the file: change command from ["/bin/launch-app"] to ["sleep", "3600"]
# Then:
kubectl apply -f 01-crashloop-pod.yaml
kubectl get pod crashloop-pod -n troubleshoot-lab
# Expected: Running
```

### Cleanup

```bash
kubectl delete pod crashloop-pod -n troubleshoot-lab
```

---

## Scenario 2 — ImagePullBackOff

### Deploy

```bash
kubectl apply -f 02-imagepull-pod.yaml
```

### Observe the symptom

```bash
kubectl get pod imagepull-pod -n troubleshoot-lab -w
```

The STATUS column shows: `ContainerCreating → ErrImagePull → ImagePullBackOff`

### Diagnose

```bash
kubectl describe pod imagepull-pod -n troubleshoot-lab
```

Focus on the `Events:` section at the bottom:

```
Warning  Failed     ...  kubelet  Failed to pull image "nginx:v99.99.99-nonexistent":
                         rpc error: code = NotFound
                         desc = failed to pull and unpack image ... not found
Warning  BackOff    ...  kubelet  Back-off pulling image "nginx:v99.99.99-nonexistent"
```

Note: `kubectl logs` will NOT work here — the container never started.

### Common causes checklist

Run through these checks when you see ImagePullBackOff:

```bash
# 1. Verify the image name and tag are correct
kubectl get pod imagepull-pod -n troubleshoot-lab \
  -o jsonpath='{.spec.containers[0].image}'

# 2. Check if imagePullSecrets are needed (for private registries)
kubectl get pod imagepull-pod -n troubleshoot-lab \
  -o jsonpath='{.spec.imagePullSecrets}'

# 3. Check node-level pull errors in events
kubectl get events -n troubleshoot-lab \
  --sort-by='.lastTimestamp' \
  --field-selector reason=Failed
```

### Root cause

The image tag `nginx:v99.99.99-nonexistent` does not exist on Docker Hub.

### Fix

Delete the pod and recreate it with a valid image:

```bash
kubectl delete pod imagepull-pod -n troubleshoot-lab

# Edit 02-imagepull-pod.yaml: change image to nginx:1.25-alpine
kubectl apply -f 02-imagepull-pod.yaml
kubectl get pod imagepull-pod -n troubleshoot-lab
```

### Cleanup

```bash
kubectl delete pod imagepull-pod -n troubleshoot-lab
```

---

## Scenario 3 — Pending Pod

### Deploy

```bash
kubectl apply -f 03-pending-pod.yaml
```

### Observe the symptom

```bash
kubectl get pod pending-pod -n troubleshoot-lab
```

STATUS is `Pending` and stays Pending — the pod never starts.

### Diagnose

```bash
kubectl describe pod pending-pod -n troubleshoot-lab
```

Look at the `Events:` section:

```
Warning  FailedScheduling  ...  default-scheduler
  0/3 nodes are available:
  3 Insufficient cpu.
  preemption: 0/3 nodes are available: 3 No preemption victims found for incoming pod.
```

This tells you exactly what the scheduler tried and why it failed.

Check current node capacity:

```bash
kubectl get nodes
kubectl describe nodes | grep -A5 "Allocatable:"
```

```bash
# See total requests vs. allocatable on each node
kubectl top nodes
```

### Root cause

The pod requests `cpu: "100"` (100 CPU cores). Standard GKE nodes have 2–16 allocatable vCPUs. The scheduler cannot find any node that satisfies this request.

### Fix

Delete the pod and recreate it with a realistic CPU request:

```bash
kubectl delete pod pending-pod -n troubleshoot-lab

# Edit 03-pending-pod.yaml: change cpu request from "100" to "100m"
kubectl apply -f 03-pending-pod.yaml
kubectl get pod pending-pod -n troubleshoot-lab
# Expected: Running
```

### Cleanup

```bash
kubectl delete pod pending-pod -n troubleshoot-lab
```

---

## Scenario 4 — Misconfigured Service (Selector Mismatch)

### Deploy

```bash
kubectl apply -f 04-misconfigured-service.yaml
```

### Observe the symptom

```bash
kubectl get pods -n troubleshoot-lab -l scenario=selector-mismatch
# Expected: 2 pods Running (the Deployment pods are fine)

kubectl get endpoints web-svc -n troubleshoot-lab
# Expected: ENDPOINTS shows <none>  ← this is the problem
```

Pods are Running but the Service cannot route to them.

### Diagnose

```bash
# Show the Service selector
kubectl describe service web-svc -n troubleshoot-lab
# Look for: Selector and Endpoints fields

# Show actual pod labels
kubectl get pods -n troubleshoot-lab \
  -l scenario=selector-mismatch \
  --show-labels
```

Compare:
- Service selector: `app=web-server`
- Pod labels: `app=web-backend`

They do not match → zero endpoints → no traffic routing.

### Further verification

Test connectivity from another pod to confirm the break:

```bash
kubectl run debug-curl -n troubleshoot-lab \
  --image=curlimages/curl:8.5.0 \
  --restart=Never \
  -- curl -s --max-time 5 http://web-svc.troubleshoot-lab.svc.cluster.local/
# Expected: curl: (7) Failed to connect  OR connection timeout
```

### Root cause

The Service selector specifies `app: web-server` but all Deployment pods are labeled `app: web-backend`. A Service routes only to pods whose labels match ALL selector key-value pairs.

### Fix

Patch the Service selector to match the pod label:

```bash
kubectl patch service web-svc -n troubleshoot-lab \
  --type merge \
  -p '{"spec":{"selector":{"app":"web-backend"}}}'
```

Verify endpoints now populate:

```bash
kubectl get endpoints web-svc -n troubleshoot-lab
# Expected: ENDPOINTS shows the pod IPs and port 80

kubectl run debug-curl -n troubleshoot-lab \
  --image=curlimages/curl:8.5.0 \
  --restart=Never \
  --rm \
  -it \
  -- curl -s --max-time 5 http://web-svc.troubleshoot-lab.svc.cluster.local/
# Expected: nginx HTML welcome page
```

### Cleanup

```bash
kubectl delete deployment web-backend -n troubleshoot-lab
kubectl delete service web-svc -n troubleshoot-lab
kubectl delete pod debug-curl -n troubleshoot-lab --ignore-not-found
```

---

## Bonus — kubectl debug (Distroless Containers)

Many production images are distroless — they have no shell (`/bin/sh`), no `curl`, no debugging tools. `kubectl exec` is useless on these containers. `kubectl debug` injects an ephemeral debug container into a running pod.

### Simulate a distroless container

```bash
# Deploy a "distroless-like" pod (gcr.io/distroless/static has no shell)
kubectl run distroless-app \
  -n troubleshoot-lab \
  --image=gcr.io/distroless/static-debian12:latest \
  --restart=Never \
  -- /bin/sleep 3600
```

Wait for it to start:

```bash
kubectl get pod distroless-app -n troubleshoot-lab
```

Try to exec in (this will fail):

```bash
kubectl exec -it distroless-app -n troubleshoot-lab -- sh
# Expected: OCI runtime exec failed: exec failed: ... no such file or directory
```

### Attach a debug sidecar

```bash
kubectl debug -it distroless-app \
  -n troubleshoot-lab \
  --image=busybox:1.36 \
  --target=distroless-app \
  --share-processes
```

Inside the debug container you can:

```sh
# Inspect the process namespace of the target container
ps aux

# Look at the target container's filesystem via /proc
ls /proc/1/root/

exit
```

### Cleanup

```bash
kubectl delete pod distroless-app -n troubleshoot-lab
```

---

## Final Cleanup

```bash
kubectl delete namespace troubleshoot-lab
```

---

## Troubleshooting Quick Reference

| Symptom | First Commands | Common Causes |
|---|---|---|
| `CrashLoopBackOff` | `describe pod`, `logs --previous` | Bad command, missing file, app error |
| `ImagePullBackOff` | `describe pod` (check Events) | Wrong tag, missing imagePullSecret, rate limit |
| `Pending` | `describe pod` (check Events) | Insufficient resources, taints, affinity mismatch |
| `Running` but unreachable | `get endpoints`, `describe svc` | Selector mismatch, wrong targetPort |
| No shell in container | `kubectl debug --image=busybox` | Distroless or scratch image |

## Key Commands Cheatsheet

```bash
# Pod status and events
kubectl describe pod <name> -n <ns>
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# Logs
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous     # last terminated instance
kubectl logs <pod> -n <ns> -c <container> # specific container in multi-container pod

# Service connectivity
kubectl get endpoints <svc> -n <ns>
kubectl run tmp --rm -it --image=curlimages/curl -- curl http://<svc>.<ns>.svc.cluster.local

# Ephemeral debug container
kubectl debug -it <pod> -n <ns> --image=busybox:1.36 --target=<container>

# Node capacity
kubectl describe nodes | grep -A5 "Allocatable:"
kubectl top nodes
```
