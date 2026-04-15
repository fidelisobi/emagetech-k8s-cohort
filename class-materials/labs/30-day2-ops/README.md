# Lab 30 — Day 2 Operations

## Overview

Day 2 operations covers everything that happens AFTER a cluster and its workloads
are running in production: backup and recovery, maintenance-safe disruption budgets,
cluster version management, and API deprecation checking.

You will:

1. Create a test namespace with a deployment, ConfigMaps, and Secrets
2. Take a Velero backup of the namespace
3. Delete the namespace, then restore it from backup
4. Verify all resources (including Secrets and ConfigMaps) are correctly restored
5. Deploy a PodDisruptionBudget and observe it block unsafe evictions
6. Check the cluster version and understand the GKE upgrade path
7. Run `kubent` to find deprecated API versions in use

**Time estimate:** 60–75 minutes

---

## Prerequisites

- kubectl configured for `cluster-dreams` in `us-central1`
- Velero installed in the `velero` namespace (verify below)
- `velero` CLI installed locally

### Verify Velero is installed

```bash
kubectl get pods -n velero
# Expected: velero-xxx pod in Running state

# Check BackupStorageLocation is available (connected to GCS)
kubectl get backupstoragelocation -n velero
# Expected: NAME      PHASE       LAST VALIDATED
#           default   Available   ...
```

### Verify the velero CLI

```bash
velero version
# Expected:
# Client:
#   Version: v1.x.x
# Server:
#   Version: v1.x.x
```

> If the velero CLI is not installed:
> ```bash
> # macOS
> brew install velero
>
> # Linux
> curl -L https://github.com/vmware-tanzu/velero/releases/latest/download/velero-v1.13.0-linux-amd64.tar.gz \
>   | tar xzf - && mv velero-*/velero /usr/local/bin/
> ```

---

## Part A — Create the Test Namespace

### Step A1 — Apply the lab manifests

```bash
kubectl apply -f 01-velero-backup.yaml
```

This creates:
- Namespace `day2-lab`
- Deployment `demo-app` (2 replicas of nginx)
- ConfigMap `demo-app-config` (with application properties)
- Secret `demo-app-secret` (with API key and database password)
- Service `demo-app`
- Velero Schedule `day2-lab-schedule` (in the `velero` namespace)

### Step A2 — Verify everything is running

```bash
kubectl get all -n day2-lab
kubectl get configmap,secret -n day2-lab
```

### Step A3 — Verify data is accessible in the pod

```bash
# Get a pod name
POD=$(kubectl get pod -n day2-lab -l app=demo-app -o jsonpath='{.items[0].metadata.name}')

# Check ConfigMap is mounted
kubectl exec $POD -n day2-lab -- cat /etc/demo/config/app.properties
# Expected: backup.test=this-config-survives-restore

# Check Secret is mounted (should show the lab secret value)
kubectl exec $POD -n day2-lab -- cat /etc/demo/secrets/api-key
# Expected: lab-secret-key-do-not-use-in-production
```

---

## Part B — Take a Velero Backup

### Step B1 — Create an on-demand backup

```bash
velero backup create test-backup \
  --include-namespaces day2-lab \
  --wait
```

The `--wait` flag blocks until the backup is complete. Without it, the command returns
immediately and the backup runs asynchronously.

Expected output:

```
Backup request "test-backup" submitted successfully.
Waiting for backup to complete. You may safely press ctrl-c to stop waiting - your backup will continue in the background.
....................
Backup completed with status: Completed. You may check for more information using the commands `velero backup describe test-backup` or `velero backup logs test-backup`.
```

### Step B2 — Verify the backup completed successfully

```bash
velero backup describe test-backup --details
```

Key fields to check:
- `Phase: Completed` (not `Failed` or `PartiallyFailed`)
- `Items Backed Up:` should show a count > 0
- `Warnings: <none>` and `Errors: <none>` ideally

```bash
# View backup logs (useful for debugging failed backups)
velero backup logs test-backup | tail -30
```

### Step B3 — List all backups

```bash
velero backup get
# OR
kubectl get backup -n velero
```

### Step B4 — Verify backup exists in GCS (optional)

```bash
gcloud storage ls gs://cluster-dreams-velero-backups/backups/test-backup/
# Expected: list of backup files (resources.json.gz, etc.)
```

> The GCS bucket name depends on how Velero was configured in your cluster.
> Check with: `kubectl get backupstoragelocation -n velero -o yaml | grep bucket`

---

## Part C — Delete the Namespace

### Step C1 — Record the current state for comparison

```bash
# Save the list of resources so you can compare after restore
kubectl get all,configmap,secret -n day2-lab > /tmp/before-delete.txt
cat /tmp/before-delete.txt
```

### Step C2 — Delete the namespace

```bash
kubectl delete namespace day2-lab
```

This deletes ALL resources in the namespace: Deployment, Pods, ConfigMaps, Secrets,
Service, PDB — everything.

Wait for the namespace to be fully deleted:

```bash
kubectl get namespace day2-lab
# Expected: Error from server (NotFound): namespaces "day2-lab" not found
```

### Step C3 — Confirm data is gone

```bash
kubectl get pods -n day2-lab
# Expected: No resources found in day2-lab namespace.
# (or NotFound error)
```

---

## Part D — Restore from Backup

### Step D1 — Create a restore from the backup

```bash
velero restore create test-restore \
  --from-backup test-backup \
  --wait
```

Velero will:
1. Read the backup from GCS
2. Recreate the namespace
3. Recreate all resources in the correct order (namespace first, then Deployments, etc.)
4. Wait for pods to be scheduled

Expected output:

```
Restore request "test-restore" submitted successfully.
Waiting for restore to complete. You may safely press ctrl-c to stop waiting.
..............
Restore completed with status: Completed.
```

### Step D2 — Verify the restore

```bash
velero restore describe test-restore
```

Check for:
- `Phase: Completed`
- `Warnings: <none>`

```bash
# Verify all resources are back
kubectl get all -n day2-lab
kubectl get configmap,secret -n day2-lab
```

### Step D3 — Verify data integrity

This is the critical check — confirm the actual data was preserved correctly.

```bash
# Wait for pods to be Running
kubectl wait --for=condition=ready pod -l app=demo-app -n day2-lab --timeout=120s

# Get a pod name
POD=$(kubectl get pod -n day2-lab -l app=demo-app -o jsonpath='{.items[0].metadata.name}')

# Verify ConfigMap data
kubectl exec $POD -n day2-lab -- cat /etc/demo/config/app.properties
# Expected: backup.test=this-config-survives-restore (same as before delete)

# Verify Secret data
kubectl exec $POD -n day2-lab -- cat /etc/demo/secrets/api-key
# Expected: lab-secret-key-do-not-use-in-production

# Compare resource list with pre-delete snapshot
kubectl get all,configmap,secret -n day2-lab > /tmp/after-restore.txt
diff /tmp/before-delete.txt /tmp/after-restore.txt
# Expected: minimal diff (timestamps and generated names will differ)
```

---

## Part E — PodDisruptionBudget

### Step E1 — Apply the PDB manifests

```bash
kubectl apply -f 02-pdb.yaml
```

This creates in the `day2-lab` namespace:
- Deployment `critical-app` with 4 replicas (zone-spread)
- PDB `critical-app-pdb` (minAvailable: 2)
- PDB `critical-app-pdb-percent` (maxUnavailable: 25%)

### Step E2 — Verify pods are running and distributed

```bash
kubectl get pods -n day2-lab -l app=critical-app -o wide
```

Note which nodes the pods are on. With topology spread constraints and 3 zones,
you should see pods distributed across different zones.

### Step E3 — Inspect the PDB

```bash
kubectl get pdb -n day2-lab
```

Expected output:

```
NAME                      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
critical-app-pdb          2               N/A               2                     30s
critical-app-pdb-percent  N/A             25%               1                     30s
```

Key column: **ALLOWED DISRUPTIONS**

- `critical-app-pdb` (minAvailable: 2, 4 replicas): allows 2 simultaneous disruptions
- `critical-app-pdb-percent` (maxUnavailable: 25%, 4 replicas): allows 1 disruption
- Both PDBs apply to the same pods; the **stricter** one governs → only 1 disruption allowed

### Step E4 — Simulate a node drain

Find a node that has a `critical-app` pod scheduled on it:

```bash
# Get node for one of the critical-app pods
kubectl get pods -n day2-lab -l app=critical-app -o wide | head -3
# Note the NODE column

NODE="<node-name-from-above>"
```

Drain the node (this triggers the eviction API for all pods on the node):

```bash
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data
```

Watch what happens:

```bash
# In another terminal — watch pod movements
kubectl get pods -n day2-lab -l app=critical-app -w
```

Expected behaviour:
- Kubernetes evicts pods one at a time (governed by the PDB)
- As each pod terminates, a replacement pod is scheduled on another node
- The drain waits for each replacement to become Ready before evicting the next
- The drain does NOT proceed in a way that would drop below 2 available pods

If you have 3+ `critical-app` pods on the drained node, the drain will block on the
3rd eviction with output like:

```
error when evicting pods/"critical-app-xxx": Cannot evict pod as it would violate
the pod's disruption budget.
```

It retries until a replacement pod becomes Ready elsewhere.

### Step E5 — Uncordon the node

```bash
kubectl uncordon $NODE
```

### Step E6 — Observe what happens with too few replicas

Scale down to 2 replicas (equal to minAvailable) and try to drain again:

```bash
kubectl scale deployment critical-app -n day2-lab --replicas=2
kubectl get pdb -n day2-lab
# ALLOWED DISRUPTIONS should now be 0 for critical-app-pdb
```

Try to evict a pod manually:

```bash
POD=$(kubectl get pod -n day2-lab -l app=critical-app -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD -n day2-lab
```

With 2 replicas and minAvailable: 2, the eviction API would block deletion.
However, `kubectl delete pod` bypasses the eviction API — PDBs only gate evictions,
not direct deletions. This is by design: PDBs protect against gradual drain, not
against emergency operations.

To see the PDB block an eviction directly:

```bash
# The eviction API is what kubectl drain uses internally
kubectl proxy &
curl -X POST http://localhost:8001/api/v1/namespaces/day2-lab/pods/$POD/eviction \
  -H 'Content-Type: application/json' \
  -d '{"apiVersion":"policy/v1","kind":"Eviction","metadata":{"name":"'$POD'","namespace":"day2-lab"}}'
# Expected: 429 Too Many Requests — disruption budget violated
```

Restore replicas:

```bash
kubectl scale deployment critical-app -n day2-lab --replicas=4
```

---

## Part F — Cluster Version and Upgrade Path

### Step F1 — Check current cluster version

```bash
kubectl version
```

Output shows both the client version and the server (cluster) version.

```bash
# For more detail on the control plane
kubectl version --output=json | python3 -m json.tool
```

### Step F2 — Check GKE channel and available upgrades

```bash
gcloud container clusters describe cluster-dreams \
  --region=us-central1 \
  --format="yaml(currentMasterVersion, releaseChannel, nodePools[].version)"
```

Key information:
- `currentMasterVersion` — current control plane version
- `releaseChannel` — which GKE release channel (RAPID, REGULAR, STABLE)
- Node pool versions — may lag behind the control plane

### Step F3 — List available upgrade versions

```bash
gcloud container get-server-config \
  --region=us-central1 \
  --format="yaml(channels)"
```

### Step F4 — Understand the GKE upgrade path

In GKE, upgrades follow these rules:

1. **Control plane first:** The control plane is upgraded before node pools
2. **Minor version skew:** Nodes can be at most 2 minor versions behind the control plane
3. **Surge upgrades:** Node pool upgrades use surge (adds nodes before removing old ones)
4. **Blue/green upgrades:** Available for zero-downtime upgrades of node pools

For a cluster on 1.29 upgrading to 1.31:
```
Step 1: Upgrade control plane: 1.29 → 1.30 (cannot skip minor versions)
Step 2: Upgrade control plane: 1.30 → 1.31
Step 3: Upgrade node pools: 1.29 → 1.31 (nodes can be up to 2 versions behind)
```

---

## Part G — Deprecated API Detection with kubent

`kubent` (kube-no-trouble) scans your cluster for resources using deprecated or
removed Kubernetes API versions. This is essential before upgrading.

### Step G1 — Install kubent

```bash
# macOS
brew install kubent

# Linux / Cloud Shell
sh -c "$(curl -sSL https://git.io/install-kubent)"
```

### Step G2 — Run the scan

```bash
kubent
```

`kubent` reads all resources from the API server and checks whether they use an API
version that has been deprecated or removed in upcoming Kubernetes versions.

Example output:

```
>>> Deprecated APIs removed in 1.29 <<<
---------------------------------------------------------------------------
KIND                NAMESPACE     NAME                    API_VERSION
FlowSchema          -             exempt                  flowcontrol.apiserver.k8s.io/v1beta2
PriorityLevelConfig -             exempt                  flowcontrol.apiserver.k8s.io/v1beta2

>>> Deprecated APIs removed in 1.32 <<<
---------------------------------------------------------------------------
KIND            NAMESPACE   NAME              API_VERSION
Ingress         production  web-ingress       networking.k8s.io/v1beta1
```

### Step G3 — Interpret the results

For each deprecated resource:
1. Note the namespace, name, and current API version
2. Find the replacement API version in the Kubernetes changelog
3. Update the resource definition in Git to use the new API version
4. Apply the updated manifest and verify no behaviour change

Common migrations:

| Old API | New API | Removed in |
|---|---|---|
| `extensions/v1beta1` Ingress | `networking.k8s.io/v1` | 1.22 |
| `policy/v1beta1` PodDisruptionBudget | `policy/v1` | 1.25 |
| `batch/v1beta1` CronJob | `batch/v1` | 1.25 |
| `autoscaling/v2beta2` HPA | `autoscaling/v2` | 1.26 |

### Step G4 — Scan specific target versions

```bash
# Only show APIs removed in Kubernetes 1.32 and later
kubent --target-version 1.32
```

---

## Cleanup

```bash
# Delete the day2 lab namespace (includes PDB, demo-app, etc.)
kubectl delete namespace day2-lab

# Remove Velero backups and restores created in the lab
velero backup delete test-backup
velero restore delete test-restore

# Verify cleanup
kubectl get namespace day2-lab
velero backup get
```

---

## Discussion Questions

1. Velero backs up the Secret resource (which contains base64-encoded data).
   Is this secure? What are the alternatives for managing secrets in backups?
2. What is the difference between a PDB `minAvailable` and a Deployment's `maxUnavailable`
   in the rolling update strategy? Do they interact?
3. What happens if a PDB blocks a node drain indefinitely? How would you handle this
   in an emergency maintenance window?
4. Why does GKE enforce sequential minor version upgrades (1.29 → 1.30 → 1.31)?
   What could go wrong with a direct skip?
5. What is the difference between Velero backup and a GKE cluster snapshot?
   When would you use each?

---

## Key Concepts

| Concept | Description |
|---|---|
| Velero Backup | Point-in-time snapshot of Kubernetes resources stored in GCS/S3 |
| Velero Schedule | Recurring Backup created on a cron schedule |
| Velero Restore | Recreate resources from a completed Backup |
| BackupStorageLocation | Pointer to the object storage bucket holding backup data |
| PodDisruptionBudget | Policy that limits voluntary pod disruptions (evictions) |
| minAvailable | Minimum pods that must remain Available during a disruption |
| maxUnavailable | Maximum pods that can be unavailable during a disruption |
| Eviction API | Kubernetes API used by `kubectl drain` — PDBs gate evictions |
| kubent | Tool that scans clusters for deprecated Kubernetes API versions |
| GKE Release Channel | RAPID / REGULAR / STABLE — controls how frequently GKE upgrades are applied |
