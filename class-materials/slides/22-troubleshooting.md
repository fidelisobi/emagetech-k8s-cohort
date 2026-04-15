# Session 22 — Troubleshooting

---

## Troubleshooting Methodology

**Analogy:** Like a doctor diagnosing a patient — symptoms first (assess), then diagnosis and treatment (fix), then post-mortem to prevent recurrence (follow-up).

### Assess
- Errors and logs
- Triggers/changes — what changed recently?
- Scope (cluster-wide, node, namespace, specific pods)
- How does it differ from baseline?

### Fix
- Compare working and non-working resources
- Isolate issues:
  - Test components directly
  - Temporarily remove affected node or pod from the pool
  - Stop the component to ensure you're communicating with the right one
  - Apply workaround/fix
  - Reproduce in sandbox environment

### Follow-Up
- Root cause analysis
- What situation was identified or not identified?
- What could be recovered or replaced automatically?
- Reproduce in a test environment

---

## Troubleshooting Decision Flowchart

```
Pod not working?
     │
     ├── Status: Pending?
     │   └──► Check: scheduling, resources, PVC, taints
     │
     ├── Status: CrashLoopBackOff?
     │   └──► Check: kubectl logs --previous, config, probes
     │
     ├── Status: ImagePullBackOff?
     │   └──► Check: image name, tag, registry auth
     │
     ├── Status: Running but not responding?
     │   └──► Check: readiness probe, service endpoints, DNS
     │
     └── Status: OOMKilled?
         └──► Check: memory limits, app memory usage
```

---

## Common Pod Errors

### CrashLoopBackOff
- Container starts, crashes, restarts — with exponential backoff
- **Debug:** `kubectl logs <pod> --previous`
- **Common causes:** missing config, wrong command/entrypoint, app error, OOM

### ImagePullBackOff / ErrImagePull
- Cannot pull container image
- **Debug:** `kubectl describe pod <name>` — check Events section
- **Common causes:** wrong image name/tag, private registry without `imagePullSecret`, registry auth expired

### OOMKilled (exit code 137)
- Container exceeded its memory limit
- **Debug:** `kubectl describe pod` — look for `Last State: Terminated, Reason: OOMKilled`
- **Fix:** increase memory limits or fix memory leak in application

### CreateContainerConfigError
- Referenced ConfigMap or Secret does not exist
- **Debug:** `kubectl describe pod` — check Events for missing references
- **Fix:** create the missing ConfigMap/Secret or fix the reference name

---

## Pending Pods & Scheduling Issues

### Insufficient Resources
- No node has enough CPU/memory to satisfy requests
- **Debug:** `kubectl describe pod` — look for `FailedScheduling` event
- **Fix:** adjust requests, add nodes, or check ResourceQuotas

### Node Selector / Affinity Mismatch
- No node matches the required labels or affinity rules
- **Debug:** check `nodeSelector` and `affinity` in pod spec vs actual node labels

### Taints with No Tolerations
- All available nodes are tainted — pod has no matching toleration
- **Debug:** `kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints`

### PVC Not Bound
- Pod references a PVC that is `Pending` (no PV available)
- **Debug:** `kubectl get pvc` — check StorageClass and available PVs
- **Fix:** ensure StorageClass exists and provisioner is working

---

## Networking Issues

### Service Not Reachable
- Check selector matches pod labels: `kubectl get endpoints <svc>`
- If endpoints list is empty — selector mismatch or no running Pods
- Verify `targetPort` matches container port

### DNS Resolution Failures
- Test: `kubectl exec -it <pod> -- nslookup <svc>.<ns>.svc.cluster.local`
- Check CoreDNS pods are running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`

### Network Policy Blocking Traffic
- Default-deny policies block all traffic unless explicitly allowed
- **Debug:** temporarily remove NetworkPolicy to isolate the issue
- Check both ingress and egress rules

### Ingress Not Working
- Check Ingress controller is running and has an external IP
- Verify Ingress rules match the request (host, path, pathType)
- Check backend Service and endpoints exist
- Check TLS certificate if using HTTPS

---

## Node Issues

### Node NotReady
- **Debug:** `kubectl describe node <name>` — check Conditions
- Common causes: kubelet stopped, network partition, resource pressure

### Resource Pressure
- MemoryPressure, DiskPressure, PIDPressure
- Node begins evicting pods when under pressure
- **Debug:** `kubectl describe node` — check Conditions section

### Taint-Based Eviction
- Nodes with `NoExecute` taints evict pods without matching tolerations
- Applied automatically when node conditions degrade

---

## Key Debug Commands

```bash
# Events (chronological)
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events -n <namespace> --field-selector reason=FailedScheduling

# Resource details and events
kubectl describe <resource> <name>

# Logs
kubectl logs <pod> -c <container>          # current container
kubectl logs <pod> --previous              # crashed/previous instance
kubectl logs <pod> --tail=100 -f           # follow last 100 lines

# Ephemeral debug containers
kubectl debug <pod> -it --image=busybox --target=<container>

# Node debugging
kubectl debug node/<node-name> -it --image=ubuntu

# Resource usage (requires metrics-server)
kubectl top pods
kubectl top nodes

# Pod details
kubectl get pods -o wide                   # IPs, nodes, status

# Temporary debug pod
kubectl run debug --rm -it --image=busybox -- sh

# Check API server connectivity
kubectl cluster-info
kubectl get --raw /healthz
```

---

## Debugging Distroless Containers with kubectl debug

Many production images are distroless — they contain no shell, no package manager, and no debugging tools. `kubectl exec` is useless against them. Use `kubectl debug` to attach an ephemeral container that shares the target container's process namespace:

```bash
# Attach a busybox sidecar that can inspect the distroless container's processes and filesystem
kubectl debug -it <pod-name> \
  --image=busybox \
  --target=<container-name> \
  --share-processes
```

- `--target` attaches the ephemeral container to the same process namespace as the named container
- `--share-processes` lets you see and signal the distroless container's processes from busybox
- The ephemeral container is discarded when the session ends — nothing is written to the pod spec permanently

**Copy-and-modify pattern** (useful when the pod itself won't start):

```bash
# Create a copy of the pod with the distroless image replaced by a debug image
kubectl debug <pod-name> -it \
  --copy-to=debug-pod \
  --set-image=<container-name>=busybox
```

This creates a new pod called `debug-pod` with `busybox` instead of the original image, so you can inspect the filesystem layout, environment variables, and mounted secrets/configmaps.

---

## Common Gotchas

| Issue | Cause | Fix |
|-------|-------|-----|
| Pod running but app not responding | Missing readiness probe — traffic sent to unready pod | Add readiness probe |
| Deployment stuck during rollout | `maxUnavailable: 0` and `maxSurge: 0` | Adjust strategy or check PDB |
| Service returns 503 | No ready endpoints | Check readiness probes and pod health |
| ConfigMap changes not picked up | Env vars sourced from ConfigMap **never** update in a running pod (require restart). Volume-mounted ConfigMaps update within ~60 seconds (kubelet sync period). | For env vars, use `kubectl rollout restart`. For volumes, changes propagate automatically within ~60s. |
| Can't delete namespace | Stuck in `Terminating` — finalizer blocking | Check for resources with finalizers, remove if safe |
| Pod evicted | Node under resource pressure | Check node conditions, set proper requests/limits |

---

## Key Takeaways

- Always start with `kubectl describe` and `kubectl get events` — most failures leave clear messages in the Events section
- `kubectl logs --previous` is essential for CrashLoopBackOff — the current log is often empty because the container crashed before writing anything
- For distroless containers, `kubectl debug` with `--target` is the only way to get a shell without rebuilding the image
- ConfigMap env vars require a pod restart to pick up changes; volume-mounted ConfigMaps update automatically within ~60 seconds (kubelet sync period)
- OOMKilled means the container hit its memory limit — increase the limit or find the memory leak; it is not a node-level issue
- Pending pods with `FailedScheduling` tell you exactly why scheduling failed — read the message carefully before scaling up nodes
- Networking problems almost always trace back to one of three things: selector mismatch (no endpoints), missing NetworkPolicy allow rule, or DNS failure
