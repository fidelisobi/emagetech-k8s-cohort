# Lab 14: Pod Lifecycle and Probes

## Overview

A pod passes through well-defined phases (Pending → Running → Succeeded/Failed) and its
containers are governed by probes, restart policies, and resource Quality of Service (QoS)
classes. In this lab you will deploy four manifests, observe pods at each phase of their
lifecycle, debug a crashing pod, and understand how the scheduler uses QoS when it needs
to evict workloads under memory pressure.

**Estimated time:** 50 minutes

**Prerequisites:**
- Completed Labs 11 and 12 (cluster connection and kubectl basics working)
- `kubectl` pointing at the shared GKE cluster

---

## Background: Pod Phases

Every pod has a `status.phase` field that summarises its lifecycle position:

| Phase | Meaning |
|---|---|
| `Pending` | The pod has been accepted by the API server but containers have not started yet (scheduling or image pull in progress) |
| `Running` | The pod has been bound to a node and at least one container is running |
| `Succeeded` | All containers have exited with code 0 and will not be restarted |
| `Failed` | All containers have terminated and at least one exited with a non-zero code |
| `Unknown` | The pod state cannot be obtained (node communication failure) |

---

## Part 1: Probes — Deploy and Observe

### 1.1 Apply the probes manifest

```bash
kubectl apply -f 01-pod-with-probes.yaml
```

### 1.2 Watch the pod start up

```bash
# -w streams updates to the terminal — press Ctrl-C when STATUS shows Running
kubectl get pod probes-demo -w
```

You will see the pod move through:
```
NAME          READY   STATUS              RESTARTS   AGE
probes-demo   0/1     Pending             0          0s
probes-demo   0/1     ContainerCreating   0          1s
probes-demo   0/1     Running             0          3s
probes-demo   1/1     Running             0          5s
```

Notice `0/1` vs `1/1` in the READY column. `0/1` means the container is running but the
readiness probe has not yet passed. Once it passes, READY becomes `1/1` and the pod
would be added to any matching Service's Endpoints.

### 1.3 Inspect the probe configuration

```bash
# kubectl describe shows probe configuration under the "Liveness" and "Readiness" sections
kubectl describe pod probes-demo
```

Look for lines like:
```
Liveness:   http-get http://:80/ delay=5s timeout=2s period=10s #success=1 #failure=3
Readiness:  http-get http://:80/ delay=2s timeout=1s period=5s  #success=1 #failure=3
Startup:    http-get http://:80/ delay=1s timeout=1s period=5s  #success=1 #failure=30
```

### 1.4 Simulate a probe failure (optional stretch)

You can make the liveness probe fail by replacing nginx's default response with a 503
status, then watching Kubernetes restart the container. This is advanced — skip if short
on time.

```bash
# Open a shell in the container
kubectl exec -it probes-demo -- /bin/bash

# Inside the container: overwrite the nginx default page so it returns 404
# (nginx returns 404 for paths it doesn't recognise with try_files)
# We'll block nginx instead by removing its PID file
# A simpler approach: rename the html file so nginx returns 404
mv /usr/share/nginx/html/index.html /usr/share/nginx/html/index.html.bak
exit

# Watch — after failureThreshold (3) consecutive 404 responses on /,
# the liveness probe will fail and kubelet will restart the container.
# The RESTARTS counter will increment.
kubectl get pod probes-demo -w
```

---

## Part 2: Init Containers

### 2.1 Apply just the pod (without the Service)

The manifest file `02-init-container.yaml` contains both a Pod and a Service separated
by `---`. Apply only the Pod first:

```bash
# We use kubectl apply with a here-doc to apply only the pod portion.
# Alternatively, split the file. For simplicity, apply the whole file:
kubectl apply -f 02-init-container.yaml
```

This creates both objects. But wait — let us first understand what you should have seen
if you applied only the pod. Delete the service to simulate the "waiting" state:

```bash
# Delete the service so the init container cannot resolve DNS
kubectl delete service my-backend-service

# Now watch the pod status
kubectl get pod init-container-demo -w
```

The pod will stay in `Init:0/1` — meaning 0 out of 1 init containers have completed.

### 2.2 Inspect the init container logs

```bash
# Read the init container's logs with -c <init-container-name>
kubectl logs init-container-demo -c wait-for-dns

# Stream the logs to watch the retry loop in real time
kubectl logs init-container-demo -c wait-for-dns -f
```

You will see repeated output like:
```
Waiting for my-backend-service to be resolvable via DNS...
DNS lookup failed. Retrying in 2 seconds...
```

### 2.3 Describe the pod to see init container status

```bash
kubectl describe pod init-container-demo
```

Look for the `Init Containers` section. It shows:
- The init container's current state (Running / Terminated / Waiting)
- How many times it has been restarted
- The last exit code

### 2.4 Unblock the init container by creating the Service

```bash
# Creating the Service registers the DNS entry my-backend-service.default.svc.cluster.local
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-backend-service
  namespace: default
spec:
  selector:
    app: my-backend
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
# Watch the pod — within one loop iteration (2 seconds) the init container will resolve
# DNS and exit 0, allowing the main nginx container to start
kubectl get pod init-container-demo -w
```

Expected transition:
```
NAME                   READY   STATUS     RESTARTS   AGE
init-container-demo    0/1     Init:0/1   0          2m
init-container-demo    0/1     PodInitializing   0   2m
init-container-demo    1/1     Running    0          2m
```

### 2.5 Verify the main container is now running

```bash
kubectl exec -it init-container-demo -- nginx -v
kubectl logs init-container-demo    # No -c flag needed — main container is the default
```

---

## Part 3: QoS Classes

### 3.1 Apply all three QoS pods

```bash
kubectl apply -f 03-qos-comparison.yaml
```

```bash
# Verify all three are running
kubectl get pods -l app=qos-demo
```

### 3.2 Inspect the QoS class of each pod

```bash
# jsonpath extracts a single field without a full yaml dump
kubectl get pod qos-guaranteed -o jsonpath='{.status.qosClass}'
echo ""

kubectl get pod qos-burstable -o jsonpath='{.status.qosClass}'
echo ""

kubectl get pod qos-besteffort -o jsonpath='{.status.qosClass}'
echo ""
```

Expected output:
```
Guaranteed
Burstable
BestEffort
```

### 3.3 Compare their resource configurations

```bash
# Print the full resource block for each pod in one command
for pod in qos-guaranteed qos-burstable qos-besteffort; do
  echo "=== $pod ==="
  kubectl get pod $pod -o jsonpath=\
'{.spec.containers[0].resources}'
  echo ""
done
```

Or read each individually:

```bash
kubectl describe pod qos-guaranteed | grep -A 6 "Limits:"
kubectl describe pod qos-burstable  | grep -A 6 "Limits:"
kubectl describe pod qos-besteffort | grep -A 6 "Limits:"
```

### 3.4 Understand the eviction order

```bash
# kubectl describe node shows which pods are running and their QoS
kubectl get nodes -o name | head -1 | xargs kubectl describe | grep -A 3 "QoS Class"
```

> **Question:** If a node runs out of memory and must evict pods, in what order would
> these three pods be evicted? Which pod should you set `Guaranteed` QoS on in
> production — a stateless HTTP frontend or a stateful database?

### 3.5 Check resource requests on the node

```bash
# kubectl describe node shows "Allocated resources" — how much is reserved
# by pods' requests. Note that BestEffort pods do NOT contribute to this total.
kubectl get nodes -o name | head -1 | xargs kubectl describe | grep -A 10 "Allocated resources"
```

---

## Part 4: CrashLoopBackOff Debugging

### 4.1 Deploy the failing pod

```bash
kubectl apply -f 04-failing-pod.yaml
```

### 4.2 Watch the CrashLoopBackOff progression

```bash
# Watch the pod — you will see STATUS cycle through:
#   ContainerCreating → Running → Error → CrashLoopBackOff
kubectl get pod crashing-pod -w
```

The RESTARTS counter increments each time the container crashes.
The time between restarts grows exponentially (10s, 20s, 40s, 80s...).

### 4.3 Read the current logs

```bash
# Read the output from the most recent container run
kubectl logs crashing-pod
```

You will see:
```
Starting application...
ERROR: Required configuration file /etc/app/config.yaml not found
Exiting with error code 1
```

### 4.4 Read logs from a previous crash (--previous)

Once the container has crashed and been restarted, the current `kubectl logs` shows
output from the NEW container run. Use `--previous` to read the terminated container's
logs:

```bash
# --previous reads logs from the last terminated container instance
kubectl logs crashing-pod --previous
```

This is critical for debugging: the current container may not have had time to log
anything before crashing, but `--previous` always has the last run's output.

### 4.5 Inspect the exit code and reason

```bash
# describe shows the "Last State" of the container including exit code
kubectl describe pod crashing-pod
```

Look for the `Last State` section:
```
Last State: Terminated
  Reason:    Error
  Exit Code: 1
  Started:   ...
  Finished:  ...
```

Exit codes reference:

| Exit Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic error |
| 2 | Shell built-in misuse |
| 137 | Killed by SIGKILL (OOMKill or `kill -9`) |
| 143 | Killed by SIGTERM (graceful termination) |

```bash
# Extract the exit code with jsonpath for scripting
kubectl get pod crashing-pod \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
echo ""

# Check how many times it has restarted
kubectl get pod crashing-pod \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo ""
```

### 4.6 Check the pod events

```bash
# Events are appended in real time — useful for seeing why a pod is in its current state
kubectl describe pod crashing-pod | grep -A 20 "Events:"
```

Look for `Back-off restarting failed container` — this confirms CrashLoopBackOff.

### 4.7 "Fix" the pod to see it recover

In real life you would fix the application. In this lab, update the command to succeed:

```bash
# Patch the command in place (kubectl patch uses strategic merge by default)
kubectl patch pod crashing-pod \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/containers/0/command/2", "value": "echo \"Fixed!\"; sleep 3600"}]'
```

> **Note:** Kubernetes does NOT allow you to patch most pod spec fields on a running pod
> (only image, active deadline, tolerations, and a few others are mutable). The patch
> above will be rejected with an error about immutable fields. This is intentional and
> teaches an important lesson: to fix a crashing pod you must DELETE and RECREATE it.

```bash
# The correct fix workflow: delete and re-apply with a corrected manifest
kubectl delete pod crashing-pod

# Edit the manifest to use a working command, then apply
# (For the lab, just delete — no need to create a working version)
```

---

## Part 5: Pod Phases and Graceful Termination

### 5.1 Watch the full lifecycle of a short-lived pod

```bash
# Apply a pod that runs for 10 seconds then exits cleanly (exit 0)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: short-lived
  labels:
    lab: "14-pod-lifecycle"
spec:
  containers:
    - name: busybox
      image: busybox:1.36
      command: ["/bin/sh", "-c", "echo 'Running for 10 seconds'; sleep 10; echo 'Done'"]
      resources:
        requests:
          cpu: "10m"
          memory: "16Mi"
        limits:
          cpu: "50m"
          memory: "32Mi"
  restartPolicy: Never    # Do NOT restart after the container exits
EOF
```

```bash
# Watch all pods in the default namespace to see phase transitions
kubectl get pods -l lab=14-pod-lifecycle -w
```

The short-lived pod will show:
```
NAME         READY   STATUS      RESTARTS   AGE
short-lived  0/1     Pending     0          0s
short-lived  0/1     ContainerCreating  0   1s
short-lived  1/1     Running     0          2s
short-lived  0/1     Completed   0          12s
```

`Completed` (shown as `Succeeded` in the phase field) means all containers exited 0
with `restartPolicy: Never`.

### 5.2 Graceful termination with --grace-period

When you delete a pod, Kubernetes sends SIGTERM to the container and waits for
`terminationGracePeriodSeconds` (default 30) before sending SIGKILL:

```bash
# Apply the probes-demo pod again if it was deleted
kubectl apply -f 01-pod-with-probes.yaml

# Wait for it to be Running
kubectl get pod probes-demo

# Delete with a short grace period — only 5 seconds before SIGKILL
# Watch the Terminating → (gone) transition
kubectl delete pod probes-demo --grace-period=5

# Open a second terminal and watch while deleting:
# (terminal 2) kubectl get pods -w
```

```bash
# Force-delete bypasses graceful termination entirely (SIGKILL immediately)
# ONLY use this if a pod is stuck in Terminating for a long time
# kubectl delete pod <name> --grace-period=0 --force
```

---

## Part 6: Putting It Together — jsonpath Queries

Practice extracting lifecycle information with `jsonpath`:

```bash
# Apply the QoS pods if they were deleted
kubectl apply -f 03-qos-comparison.yaml

# Get the phase of every pod in the default namespace in one shot
kubectl get pods -l lab=14-pod-lifecycle \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Get QoS class of every pod
kubectl get pods -l lab=14-pod-lifecycle \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}'

# Get restart count of every pod's first container
kubectl get pods -l lab=14-pod-lifecycle \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```

---

## Clean Up

```bash
# Delete all resources created in this lab
kubectl delete pod probes-demo init-container-demo \
  qos-guaranteed qos-burstable qos-besteffort \
  crashing-pod short-lived \
  --ignore-not-found

# Delete the service created for the init container lab
kubectl delete service my-backend-service --ignore-not-found

# Verify everything is gone
kubectl get pods -l lab=14-pod-lifecycle
```

---

## Summary

After completing this lab you should be able to:

- Explain the three probe types (startup, readiness, liveness) and when each is used
- Read probe configuration from `kubectl describe pod` output
- Explain why init containers are useful and trace their execution in logs
- Identify the QoS class of a pod from `kubectl get pod -o jsonpath='{.status.qosClass}'`
- Explain which pods Kubernetes evicts first under memory pressure and why
- Debug a CrashLoopBackOff pod using `kubectl logs`, `kubectl logs --previous`, and `kubectl describe`
- Interpret common exit codes (0, 1, 137, 143)
- Use `kubectl delete pod --grace-period` to control termination timing
- Watch real-time pod phase transitions with `kubectl get pods -w`
