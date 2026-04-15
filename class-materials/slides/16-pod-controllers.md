# Session 16 — Managed Pods (Pod Controllers)

---

## Applications

| Type | Long Running | Short Running |
|------|-------------|---------------|
| **Stateless** | Deployment/ReplicaSet, DaemonSet | Jobs, CronJobs |
| **Stateful** | StatefulSet | Jobs, CronJobs |

---

## Managed Pods

Managed by specific pod controllers:
- Deployment
- ReplicaSet
- StatefulSet
- Jobs
- CronJobs

All require a **Pod Template** — specifications for creating pods.

---

## ReplicaSet (RS)

- A pod controller with the sole purpose of maintaining a stable set of pod replicas at any given time
- Like other pod controllers, requires a pod template
- Must have a selector which matches the labels in the pod template
- Is linked to its pods via the Pod's `metadata.ownerReferences` field
- ReplicaSets can acquire other unmanaged pods that match its selector
- Appends a 5-character hash to pods it manages

---

## Deployment (DEPLOY)

A controller which manages ReplicaSets.

**Main fields in `deployment.spec`:**
- `replicas`
- `selector` (matchLabels or matchExpressions)
- `template` (pod template)
- `strategy`:
  - **Recreate** — there is some downtime
  - **RollingUpdate** (default)
    - `maxSurge` — max pods over desired count during update
    - `maxUnavailable` — max pods that can be unavailable during update

- Appends a `pod-template-hash` to ReplicaSets it creates
- Linked to its ReplicaSets via `metadata.ownerReferences`

---

## Deployment Ownership Chain

A Deployment manages ReplicaSets; ReplicaSets manage Pods. Old ReplicaSets are kept at 0 replicas to enable rollback.

```
Deployment (my-app)
├── ReplicaSet (my-app-7d9f4b) ← current (3 replicas)
│   ├── Pod (my-app-7d9f4b-xk8p)
│   ├── Pod (my-app-7d9f4b-mn4q)
│   └── Pod (my-app-7d9f4b-r7wj)
└── ReplicaSet (my-app-5c6b9d) ← previous (0 replicas, kept for rollback)
```

---

## Deployment YAML Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # allow 1 extra pod above desired count
      maxUnavailable: 0     # never go below desired count during rollout
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: my-app:v2
          ports:
            - containerPort: 8080
```

---

## RollingUpdate Step-by-Step

With `maxSurge: 1`, `maxUnavailable: 0`, and 3 replicas, Kubernetes surgically replaces one pod at a time:

```
Step 1: [v1] [v1] [v1]          ← 3 old pods running
Step 2: [v1] [v1] [v1] [v2]    ← 1 new pod created (maxSurge=1)
Step 3: [v1] [v1] [v2]          ← 1 old pod terminated
Step 4: [v1] [v1] [v2] [v2]    ← 1 new pod created
Step 5: [v1] [v2] [v2]          ← 1 old pod terminated
Step 6: [v1] [v2] [v2] [v2]    ← 1 new pod created
Step 7: [v2] [v2] [v2]          ← rollout complete
```

---

## Deployment - Rollouts

- Used to manage rollout strategies
- Rollouts can be paused, restarted, resumed, or reverted
- Rollouts are associated with **Revisions**
  - `kubectl rollout history deployment/<name>`
- Revisions are associated with specific ReplicaSets created by deployments

```bash
kubectl rollout status deployment/<name>     # watch rollout progress
kubectl rollout history deployment/<name>    # view revision history
kubectl rollout undo deployment/<name>       # rollback to previous
kubectl rollout undo deployment/<name> --to-revision=2  # rollback to specific
kubectl rollout pause deployment/<name>      # pause rollout
kubectl rollout resume deployment/<name>     # resume rollout
```

---

## Other Deployment Strategies

> **Important:** Canary, Blue/Green, A/B Testing, and Shadowing are NOT native Kubernetes Deployment strategies. They require external tooling layered on top of Deployments.

- **Canary** — create small number of pods, let them receive traffic. If they behave as expected, replace all other pods. Implemented via Argo Rollouts, Flagger, or some Ingress Controllers.
- **A/B Testing** — a small number of pods for a subset of users/traffic based on selected criteria. Use a Service Mesh (Istio or Linkerd).
- **Blue/Green** — old and new pod versions run in parallel. Switch traffic all at once to new pods. Use a Service or special Ingress.
- **Shadowing** — old and new pod versions run in parallel. Mirror the old pods' traffic to new pods, but end-users interact with old pods. Use a Service Mesh. Also called a "dark launch."

**Decision guide:**
- Use **Blue/Green** for instant rollback with zero mixed versions.
- Use **Canary** to validate before full rollout.
- Use **Shadowing** to test under real load with zero user impact.

---

## DaemonSet (DS)

- Ensures all (or some) nodes run a copy of a pod
- Pods get added or removed as nodes are added or removed
- Has a pod template but **replicas are not specified**
- Use Cases:
  - System-level pods (cluster-level logs, storage, monitoring)
- Examples: CNI (networking), CSI (storage)
- Can be deployed to a subset of nodes using `nodeSelector`

**Rollout Strategies:** OnDelete & RollingUpdate
- Has revisions and can be rolled back like Deployments

---

## StatefulSet (STS)

- Stateful workloads must store and maintain state to function
- Usually harder to scale (can't add/remove replicas without considering state)

**Pets vs Cattle:**
- Stateless Workloads == Cattle == Deployments
- Stateful Workloads == Pets == StatefulSets

**Key Characteristics:**
- Each pod gets its own Persistent Volume
- Each pod is addressable by its unique address
- Named in an ordinal method (pod-0, pod-1, pod-2). Deployments are randomly named
- Deleting a STS pod generates a pod with the **same name and persistent volume**
- Unlike Deployments, pods are not exact copies — they have different PVs

```
StatefulSet: postgres
├── Pod: postgres-0  ←→  PVC: data-postgres-0
├── Pod: postgres-1  ←→  PVC: data-postgres-1
└── Pod: postgres-2  ←→  PVC: data-postgres-2
```

Each pod's PVC is created automatically from a `volumeClaimTemplate` and persists independently — deleting the pod does not delete the PVC.

**Best Practice:** Use a dedicated persistent volume for each replica.

**Node Failure:**
- StatefulSet does NOT automatically replace the pod (unlike Deployments)
- Requires manual intervention for the pod to be recreated
- Pod may not restart if the volume is local to the node

---

## Jobs & CronJobs

Pod controllers for managing pods with **finite workloads**.

**Job Execution Methods:**
- Non-parallel jobs
- Parallel jobs

**Key Fields:**
- `completions` — number of pods that must successfully complete
- `parallelism` — how many pods can run in parallel
- `backoffLimit` — retries before marking as failed (default = 6)
- `activeDeadlineSeconds` — total runtime for the job

**Restart Policies:** OnFailure or Never (not Always)

**Pod-Level Failures:**
- Restart policy `OnFailure` → container restarted by kubelet
- Restart policy `Never` → pod recreated by Job controller

**Scenario — parallel data migration:**

Run a data migration across 5 partitions, 2 at a time:

```yaml
spec:
  completions: 5    # 5 total partitions to process
  parallelism: 2    # process 2 partitions at a time
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrator
          image: my-migrator:v1
```

---

## CronJobs

- Creates Jobs on a schedule
- Used for: backups, report generation, cleanup tasks

**Key Fields:**
- `schedule` — cron expression
- `startingDeadlineSeconds` — deadline for starting a missed job (default is `nil` — no deadline; the job will run as soon as the controller catches up)
- `concurrencyPolicy`:
  - **Allow** (default) — allows concurrent jobs
  - **Forbid** — does not allow concurrency
  - **Replace** — new job replaces previous even if unfinished
- `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`
- Can be suspended: `kubectl patch cj <name> -p '{"spec":{"suspend": true}}'`

---

## Key Takeaways

- **Deployments** manage ReplicaSets, which manage Pods. Old ReplicaSets are kept at 0 replicas so you can roll back instantly.
- A **RollingUpdate** with `maxSurge=1, maxUnavailable=0` replaces pods one at a time with zero downtime.
- **StatefulSets** give each pod a stable identity and a dedicated PVC that survives pod restarts and deletions.
- **Canary, Blue/Green, A/B, and Shadowing** are not native Kubernetes strategies — they require Argo Rollouts, Flagger, or a service mesh.
- **Jobs** support parallel execution via `completions` + `parallelism`; useful for batch workloads like data migrations.
- **CronJobs** default `startingDeadlineSeconds` is `nil` (no deadline) — not 30s. Set it explicitly if your job is time-sensitive.
- Choose your controller based on workload type: Deployment for stateless, StatefulSet for stateful, DaemonSet for node-level agents, Job/CronJob for finite tasks.

---

## Review Questions

### Beginner

1. What is the relationship between a Deployment, a ReplicaSet, and a Pod? Why does Kubernetes keep old ReplicaSets around at 0 replicas?
2. What is the difference between `maxSurge` and `maxUnavailable` in a RollingUpdate strategy? What happens if you set both to 0?
3. What is a DaemonSet used for, and how does it decide how many pod replicas to run?
4. What is the key difference between a Job and a CronJob? Give one practical use case for each.
5. What makes a StatefulSet different from a Deployment when it comes to pod naming and storage?

### Intermediate

1. You have a Deployment with 5 replicas and need to roll out a new image version with zero downtime and the ability to instantly roll back. What `strategy` settings would you configure, and what `kubectl` command would you run to revert to the previous version if the rollout goes wrong?
2. A StatefulSet pod (`postgres-1`) gets killed because its node fails. Explain why the pod might not automatically come back up, how that differs from how a Deployment handles node failures, and what you would need to do to recover.
3. What is the difference between the Canary and Blue/Green deployment strategies? For each one, describe a scenario where it would be the better choice and identify which additional Kubernetes tooling would be required to implement it.
