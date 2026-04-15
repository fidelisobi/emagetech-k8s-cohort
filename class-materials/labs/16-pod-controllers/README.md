# Lab 16 — Pod Controllers

## Overview

Pod controllers manage the lifecycle of pods so you don't have to. In this lab you will work with the four most important controllers:

1. **Deployment** — manages stateless replicated workloads, rolling updates, and rollbacks
2. **StatefulSet** — manages stateful workloads with stable identities and ordered operations
3. **Job** — runs pods to completion (batch processing)
4. **CronJob** — runs Jobs on a time schedule

**Time estimate:** 50–60 minutes

---

## Prerequisites

- A running GKE cluster with `kubectl` configured
- Basic familiarity with `kubectl get`, `describe`, `logs`

---

## Step 1 — Create the Namespace

```bash
kubectl create namespace controllers-lab
```

---

## Part A — Deployment

### Step A1 — Deploy

```bash
kubectl apply -f 01-deployment.yaml
```

Watch the rollout:

```bash
kubectl rollout status deployment/web-app -n controllers-lab
```

List pods and note the ReplicaSet hash suffix in the pod names:

```bash
kubectl get pods -n controllers-lab -l app=web-app
```

Expected output (3 pods, all Running):

```
NAME                       READY   STATUS    RESTARTS   AGE
web-app-6d7f9b4c5d-abc12   1/1     Running   0          30s
web-app-6d7f9b4c5d-def34   1/1     Running   0          30s
web-app-6d7f9b4c5d-ghi56   1/1     Running   0          30s
```

### Step A2 — Inspect the Ownership Chain

Kubernetes uses owner references to link objects. The chain is:

```
Deployment → ReplicaSet → Pod
```

List ReplicaSets:

```bash
kubectl get replicaset -n controllers-lab
```

Describe a ReplicaSet to see its owner reference (the Deployment):

```bash
kubectl describe replicaset -n controllers-lab -l app=web-app
```

Look at the `Controlled By:` line — it points to the Deployment.

Describe a pod to see its owner reference (the ReplicaSet):

```bash
POD=$(kubectl get pod -n controllers-lab -l app=web-app -o name | head -1)
kubectl describe $POD -n controllers-lab | grep "Controlled By"
```

### Step A3 — Trigger a Rolling Update

Update the image tag to trigger a rolling update:

```bash
kubectl set image deployment/web-app web=nginx:1.27-alpine -n controllers-lab
kubectl annotate deployment web-app kubernetes.io/change-cause="update to nginx 1.27" -n controllers-lab
```

Watch the rollout in real time (open a second terminal if possible):

```bash
kubectl rollout status deployment/web-app -n controllers-lab -w
```

While rolling out, observe the extra pod created by `maxSurge: 1`:

```bash
kubectl get pods -n controllers-lab -l app=web-app
# You should briefly see 4 pods (3 desired + 1 surge)
```

After the rollout, list ReplicaSets again:

```bash
kubectl get replicaset -n controllers-lab
```

You will see TWO ReplicaSets — the old one (0 desired, 0 ready) and the new one (3 ready). Kubernetes keeps the old one for rollback purposes.

### Step A4 — Rollback

View rollout history:

```bash
kubectl rollout history deployment/web-app -n controllers-lab
```

Roll back to the previous version:

```bash
kubectl rollout undo deployment/web-app -n controllers-lab
```

Confirm the rollback completed:

```bash
kubectl rollout status deployment/web-app -n controllers-lab
kubectl get pods -n controllers-lab -l app=web-app -o wide
```

Verify the image reverted:

```bash
kubectl get deployment web-app -n controllers-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: nginx:1.25-alpine
```

---

## Part B — StatefulSet

### Step B1 — Deploy

```bash
kubectl apply -f 02-statefulset.yaml
```

Watch pods appear in ORDER (db-0 first, then db-1, then db-2):

```bash
kubectl get pods -n controllers-lab -l app=db -w
```

Notice the pod names: `db-0`, `db-1`, `db-2` — predictable, ordinal names (unlike Deployment pod names which have a random suffix).

### Step B2 — Verify DNS Identity

Each StatefulSet pod gets a stable DNS name via the headless Service:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

Exec into db-0 and look up db-1 by name:

```bash
kubectl exec -it db-0 -n controllers-lab -- sh
```

Inside the container:

```sh
# Your own hostname is your ordinal name
hostname
# Expected: db-0

# nslookup another pod by stable DNS name
nslookup db-1.db-headless.controllers-lab.svc.cluster.local

exit
```

### Step B3 — Delete a Pod and Watch Replacement

Unlike Deployments (which create a pod with a new random name), a StatefulSet always recreates the SAME pod name:

```bash
kubectl delete pod db-1 -n controllers-lab

# Watch — it comes back as db-1, not a new random name
kubectl get pods -n controllers-lab -l app=db -w
```

---

## Part C — Job

### Step C1 — Run the Job

```bash
kubectl apply -f 03-job.yaml
```

Watch pod completions (parallelism: 2 means 2 pods run at once):

```bash
kubectl get pods -n controllers-lab -l app=batch-processor -w
```

You should see pods moving through `Pending → Running → Completed`. At most 2 are in Running state simultaneously.

### Step C2 — Inspect Completions

```bash
kubectl get job batch-processor -n controllers-lab
```

Expected output:

```
NAME               COMPLETIONS   DURATION   AGE
batch-processor    5/5           35s        45s
```

Check logs from any completed pod:

```bash
kubectl logs -n controllers-lab -l app=batch-processor --tail=5
```

### Step C3 — Describe the Job

```bash
kubectl describe job batch-processor -n controllers-lab
```

Note the `Pods Statuses` line showing `Succeeded: 5`.

> The Job auto-deletes 120 seconds after completion (`ttlSecondsAfterFinished: 120`). If it has already disappeared, that is expected behavior.

---

## Part D — CronJob

### Step D1 — Create the CronJob

```bash
kubectl apply -f 04-cronjob.yaml
```

List the CronJob:

```bash
kubectl get cronjob -n controllers-lab
```

Expected (SCHEDULE shows `*/1 * * * *`):

```
NAME               SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
timestamp-logger   */1 * * * *   False     0        <none>          10s
```

### Step D2 — Watch Jobs Being Created

The CronJob creates a new Job every minute. Watch the jobs list:

```bash
kubectl get jobs -n controllers-lab -w
```

After a minute or two you will see jobs appearing with names like `timestamp-logger-12345678`.

Check logs from a completed job pod:

```bash
kubectl logs -n controllers-lab -l app=timestamp-logger --tail=6
```

### Step D3 — Suspend the CronJob

Suspending stops new runs without deleting the CronJob:

```bash
kubectl patch cronjob timestamp-logger -n controllers-lab \
  -p '{"spec":{"suspend":true}}'
```

Confirm it is suspended:

```bash
kubectl get cronjob timestamp-logger -n controllers-lab
# SUSPEND column should show: True
```

Wait a minute and confirm no new Jobs are created:

```bash
kubectl get jobs -n controllers-lab
```

---

## Discussion Questions

1. What is the difference between `maxSurge` and `maxUnavailable` in a RollingUpdate? When would you set `maxUnavailable: 1`?
2. Why does Kubernetes keep the old ReplicaSet after a rolling update?
3. In a StatefulSet, what guarantee does the headless Service provide that a regular ClusterIP Service does not?
4. When would you choose `restartPolicy: OnFailure` vs `restartPolicy: Never` in a Job?
5. What happens to missed CronJob runs if the cluster is offline for 2 hours? (Hint: check `startingDeadlineSeconds`)

---

## Cleanup

```bash
kubectl delete namespace controllers-lab
```

---

## Key Concepts

| Controller | Use Case | Pod Names | Ordering |
|---|---|---|---|
| Deployment | Stateless replicas | Random suffix | Unordered |
| StatefulSet | Stateful, stable identity | Ordinal (0, 1, 2...) | Ordered start/stop |
| Job | One-time batch tasks | Random suffix | Parallel possible |
| CronJob | Scheduled batch tasks | Random suffix | Per schedule |
