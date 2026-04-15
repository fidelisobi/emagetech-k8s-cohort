# Session 14 — Pod Lifecycle

---

## Pods

- A co-located & co-scheduled group of containers
- The basic building block in Kubernetes
- Containers ideally should run a single process
- Multiple containers in a pod should run closely related processes
- Multiple containers within a Pod share the same Linux namespaces

---

## Pod Types

- **Managed Pods** — managed by pod controllers (Deployment, ReplicaSet, StatefulSet, Jobs, CronJobs)
- **Unmanaged Pods** — created directly (not recommended for production)
- **Static Pods** — managed directly by the kubelet, without the control plane managing or scheduling them

---

## Pods - Resource Sharing

- Containers within a Pod can share the same storage volume
- Containers within a Pod share the same networking namespaces:
  - Same IP
  - Same port space
  - Same hostname

---

## Pod Lifecycle - Pod Phase

> **Analogy:** Think of a package being shipped. Pending = accepted at the warehouse, waiting for a truck. Running = on the truck, in transit. Succeeded = delivered. Failed = returned to sender. Unknown = the truck's GPS stopped transmitting.

| Phase | Description |
|-------|-------------|
| **Pending** | Pod accepted by cluster. Waiting to be scheduled. Downloading container image |
| **Running** | Pod scheduled, image downloaded & at least one container is running or starting up |
| **Succeeded** | Containers terminated in success. Occurs with short-lived pods |
| **Failed** | At least one container terminated in failure (non-zero exit code or terminated by system) |
| **Unknown** | Status of pod is unknown. Usually occurs if kubelet or node is down |

> **Note:** A pod can be "Running" while a container inside it is "Waiting" — phases are a high-level summary of the pod, container states are the fine-grained view.

---

## Pod Phase State Diagram

```
           ┌──────────┐
  create──►│ Pending  │
           └────┬─────┘
                │ scheduled + image pulled
                ▼
           ┌──────────┐
           │ Running  │──────────────────┐
           └────┬─────┘                  │
                │                        │ node lost
        ┌───────┴───────┐           ┌────▼─────┐
        ▼               ▼           │ Unknown  │
   ┌──────────┐   ┌──────────┐     └──────────┘
   │Succeeded │   │  Failed  │
   └──────────┘   └──────────┘
```

---

## Pod Lifecycle - Pod Conditions

- PodHasNetwork
- PodScheduled
- ContainersReady
- Initialized
- Ready

---

## Pod Lifecycle - Container States

| State | Description |
|-------|-------------|
| **Waiting** | Container is still running operations required for startup (pulling image, applying secrets) |
| **Running** | Container is running without issues |
| **Terminated** | Ran to completion or failed for some reason |

---

## Pod Lifecycle - Container Restart Policy

Refers to the restart of containers by the kubelet on the same node. Applies to all containers in the pod.

| Policy | Use Case |
|--------|----------|
| **Always** (default) | Long-running containers |
| **OnFailure** | Used in K8s Jobs |
| **Never** | Run once only |

---

## Pod Health Checks - Probes

> **Analogy:** Think of three hospital checks. Startup probe = "Is the patient out of surgery?" (no other tests until this passes). Readiness probe = "Is the patient well enough to see visitors?" (controls traffic). Liveness probe = "Is the patient still breathing?" (if not, intervene immediately).

Probes are diagnostic health checks performed periodically by the kubelet on a container.

**Check Mechanisms:**
- **Exec** — executes a command inside the container. Success == exit code 0
- **httpGet** — performs HTTP GET against pod IP:port. Success == status code >= 200, < 400
- **tcpSocket** — performs TCP check against pod IP:port
- **gRPC** — performs gRPC health check

**Outcomes:** Success, Failure, Unknown

---

## Startup / Readiness / Liveness Probes

**Startup Probe:**
- Verifies if the application in a container is started
- Other probes are disabled until startup probe succeeds
- Success → other probes can begin
- Failure → kubelet kills/restarts container(s) based on restartPolicy

**Readiness Probe:**
- Reports if the Pod is ready to accept traffic
- Success → Kubernetes begins sending traffic to Pod
- Failure → Kubernetes stops sending traffic to the Pod

**Liveness Probe:**
- Reports if the application is up and running
- Runs only when Pod is in a Running state
- Success → no action taken
- Failure → kubelet kills/restarts container(s) based on restartPolicy

**Demo:** https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

---

## Probe Timing Diagram

```
Pod starts
│
├── Startup Probe fires ──────────────────────┐
│   (other probes disabled)                   │
│                                             ▼ Success
├── Readiness Probe begins ──► Controls traffic routing
│
├── Liveness Probe begins  ──► Restarts container on failure
│
▼ (both run concurrently until pod terminates)
```

---

## Probe YAML Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:1.0
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
      startupProbe:
        httpGet:
          path: /healthz
          port: 8080
        failureThreshold: 30
        periodSeconds: 10          # up to 5 min for slow-starting apps
      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 10
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 15
        periodSeconds: 20
        failureThreshold: 3
```

---

## Pods - Termination

**Graceful Termination Timeline:**

```
kubectl delete pod
     │
     ▼ Pod status → Terminating
     │ Removed from Service endpoints (no new traffic)
     │ SIGTERM sent to container process
     │
     │ ◄── grace period (default 30s) ──►
     │     App should finish in-flight requests
     │
     ▼ SIGKILL sent (if still running)
     ▼ Pod removed from API server
```

**Forceful Pod Termination:**
- `kubectl delete pod --grace-period=0 --force`
- Generates a SIGKILL and does not wait for the API Server to confirm Pod removal

---

## Pod Containers

**Init Containers:**

> **Analogy:** Init containers are like the prep crew setting the stage before the main performance — they run, finish their job, then the main act begins.

- Specialized containers that run before application containers
- Features:
  - Always runs to completion
  - Each init container must complete successfully before the next one starts
- Use Cases:
  - Initialize files in volumes used by the pod's main container
  - Initialize the pod's networking system
  - Delay pod startup until preconditions are met
  - Notify external service that pod is about to start running

**Practical Example — Wait for database before starting app:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          until nc -z postgres-service 5432; do
            echo "waiting for postgres...";
            sleep 2;
          done
          echo "postgres is up"
  containers:
    - name: app
      image: my-app:1.0
```

**Ephemeral Containers:**
- Useful for interactive troubleshooting of distroless images
- Created using `kubectl debug` command

---

## Sidecar Containers

- Placing several containers in a single pod is **only** appropriate if the app consists of a primary process and one or more processes that complement the primary process
- Complementary process runs as a sidecar container (analogous to a motorcycle sidecar)

**Use Cases:**
- Log rotators & collectors
- Data processors
- Communication adapters (Istio, Linkerd, DAPR)

---

## Pods/Containers - Resource Management

**Resource Types:** CPU, Memory (gotten from the node)

**Requests:**
- Specifies resource required by the container
- kube-scheduler uses this info to schedule pods

**Limits:**
- Specifies max resource a container is allowed to utilize
- Limits are enforced by the kubelet/container runtime
- Limits >= Requests

**CPU Units:**
- 1 CPU unit == 1 virtual core
- 0.1 CPU unit == 100m (millicores)
- 1 CPU unit == 1000m (millicores)

**Memory Units:**
- Measured in bytes: E, P, T, G, M, k OR Ei, Pi, Ti, Gi, Mi, Ki

---

## Resource Behavior

- **CPU is compressible** — can be stretched to satisfy demand
  - At CPU limits → containers are **throttled**
- **Memory is non-compressible** — cannot be stretched
  - At memory limits → containers are **OOM killed**

---

## Quality of Service (QoS)

> **Analogy:** In a hotel at full capacity: BestEffort guests (no reservation guarantee) are evicted first. Burstable guests (standard room) are middle. Guaranteed guests (confirmed suite) are last to go.

QoS classes are used to influence how pods are handled when resources are constrained. All pods are assigned a QoS class based on their resource requests and limits.

| QoS Class | Condition | Eviction Priority |
|-----------|-----------|-------------------|
| **Guaranteed** | Request == Limit | Last to be evicted |
| **Burstable** | Limit > Request, or only Request is defined | Middle |
| **BestEffort** | Neither Limit nor Request configured | First to be evicted |

**QoS YAML Comparison:**

```yaml
# Guaranteed — requests == limits for all containers
resources:
  requests:
    cpu: "500m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"

---

# BestEffort — no requests or limits set
resources: {}

---

# Burstable — limits exceed requests (or only requests defined)
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

---

## Pod Disruption Budgets (PDB)

- Limits the number of pods that can be simultaneously disrupted during voluntary disruptions
- Ensures application availability during maintenance (node drains, upgrades)
- Key fields:
  - `minAvailable` — minimum pods that must remain available
  - `maxUnavailable` — maximum pods that can be unavailable
- Does NOT protect against involuntary disruptions (node crashes, OOM)

---

## Key Takeaways

1. **Pod phases are a high-level summary** — a pod can be "Running" while a container inside is still "Waiting." Always check container states for the full picture.
2. **Use all three probes together for production workloads** — startup probe protects slow-starting apps, readiness controls traffic, liveness triggers self-healing.
3. **SIGTERM is your friend — handle it in code** — your app must catch SIGTERM and drain gracefully within the 30-second window; SIGKILL gives no opportunity to clean up.
4. **Init containers are the right tool for dependency ordering** — prefer them over sleep loops or retry logic in your main container.
5. **QoS is implicit, not declared** — Kubernetes derives it from your resource requests and limits. Set requests == limits for critical workloads to get Guaranteed class.
6. **BestEffort pods are eviction targets** — never run production workloads without resource requests.
