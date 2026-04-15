# Lab 20 — Persistent Storage

## Overview

Container filesystems are ephemeral — data written inside a container is lost when the pod is deleted. In this lab you will use PersistentVolumeClaims (PVCs) to attach durable storage to pods, and StatefulSet `volumeClaimTemplates` to give each replica its own isolated volume. You will:

1. Create a PVC backed by a GCE Persistent Disk and verify it binds
2. Write data from a pod, delete the pod, and confirm data survives
3. Deploy a StatefulSet with `volumeClaimTemplates` to see per-pod PVCs
4. Scale down the StatefulSet and verify PVCs are NOT deleted
5. Manually clean up PVCs

**Time estimate:** 40–50 minutes

---

## Prerequisites

- A running GKE cluster with `kubectl` configured
- The `standard` StorageClass must be available (default on GKE)
- Check: `kubectl get storageclass`

---

## Step 1 — Create the Namespace

```bash
kubectl create namespace storage-lab
```

---

## Step 2 — Create the PVC and Verify Binding

```bash
kubectl apply -f 01-pvc.yaml
```

Check the PVC status — it should transition from `Pending` to `Bound`:

```bash
kubectl get pvc -n storage-lab -w
```

Expected output after ~10 seconds:

```
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
app-data-pvc   Bound    pvc-a1b2c3d4-...                          1Gi        RWO            standard       15s
```

Inspect the auto-created PersistentVolume:

```bash
kubectl get pv
```

Describe the PVC to see which PV it bound to and the reclaim policy:

```bash
kubectl describe pvc app-data-pvc -n storage-lab
```

Note the `VolumeHandle` — this is the Google Persistent Disk resource ID in GCE.

---

## Step 3 — Write Data from the Writer Pod

Deploy only the writer pod from the combined file:

```bash
# Apply the whole file — both pods start, but we'll use them sequentially
kubectl apply -f 02-pod-with-pvc.yaml
```

Wait for writer-pod to be Running:

```bash
kubectl get pods -n storage-lab -w
```

Check the writer's logs to confirm the file was written:

```bash
kubectl logs writer-pod -n storage-lab
```

Exec in and verify the file:

```bash
kubectl exec -it writer-pod -n storage-lab -- sh
```

Inside:

```sh
ls -la /data/
cat /data/message.txt
exit
```

---

## Step 4 — Delete the Writer Pod and Verify Data Persists

Delete writer-pod (the PVC is NOT deleted — only the pod):

```bash
kubectl delete pod writer-pod -n storage-lab
```

Confirm writer-pod is gone but the PVC still exists:

```bash
kubectl get pods -n storage-lab
kubectl get pvc -n storage-lab
# PVC should still be Bound
```

### Wait for reader-pod

The reader-pod was already created in Step 3. Check its status:

```bash
kubectl get pod reader-pod -n storage-lab
```

If it is stuck in `ContainerCreating` it is waiting for the disk to detach from the deleted pod's node and reattach to the new node. This is normal for RWO volumes and may take 30–60 seconds.

Once Running, check the reader's logs:

```bash
kubectl logs reader-pod -n storage-lab
```

Exec in to verify:

```bash
kubectl exec -it reader-pod -n storage-lab -- sh
```

Inside:

```sh
cat /data/message.txt
# Expected: the message written by writer-pod — data survived!
exit
```

> **Key insight:** The PVC (and the underlying GCE Persistent Disk) exists independently of pods. Deleting a pod does NOT delete a PVC.

---

## Step 5 — Deploy the StatefulSet with Per-Pod PVCs

```bash
kubectl apply -f 03-statefulset-storage.yaml
```

Watch pods come up in order:

```bash
kubectl get pods -n storage-lab -l app=db-store -w
```

List the auto-created PVCs — one per pod:

```bash
kubectl get pvc -n storage-lab
```

Expected output:

```
NAME                 STATUS   VOLUME          CAPACITY   STORAGECLASS   AGE
app-data-pvc         Bound    pvc-...         1Gi        standard       5m
data-db-store-0      Bound    pvc-...         1Gi        standard       30s
data-db-store-1      Bound    pvc-...         1Gi        standard       25s
data-db-store-2      Bound    pvc-...         1Gi        standard       20s
```

Verify each pod wrote to ITS OWN PVC:

```bash
kubectl exec db-store-0 -n storage-lab -- cat /data/pod-identity.txt
kubectl exec db-store-1 -n storage-lab -- cat /data/pod-identity.txt
kubectl exec db-store-2 -n storage-lab -- cat /data/pod-identity.txt
```

Each file should contain a different hostname (`db-store-0`, `db-store-1`, `db-store-2`).

---

## Step 6 — Scale Down and Verify PVCs Are Retained

Scale the StatefulSet down to 0:

```bash
kubectl scale statefulset db-store -n storage-lab --replicas=0
```

Wait for all pods to terminate:

```bash
kubectl get pods -n storage-lab -l app=db-store -w
```

Now check the PVCs:

```bash
kubectl get pvc -n storage-lab
```

All three PVCs (`data-db-store-0`, `data-db-store-1`, `data-db-store-2`) are still `Bound` even though no pods are running. Kubernetes deliberately does NOT delete PVCs when a StatefulSet is scaled down or even deleted — this protects your data.

Scale back up and verify data is still there:

```bash
kubectl scale statefulset db-store -n storage-lab --replicas=3
kubectl exec db-store-0 -n storage-lab -- cat /data/pod-identity.txt
# Data should still be present
```

---

## Step 7 — Discussion Questions

1. What is the difference between a PersistentVolume and a PersistentVolumeClaim?
2. Why does `ReadWriteOnce` (RWO) cause scheduling constraints?
3. Why are StatefulSet PVCs NOT deleted when the StatefulSet is deleted?
4. What is the `reclaimPolicy` of the `standard` StorageClass on GKE? What happens to the GCE disk when you delete the PVC?
5. When would you use `ReadWriteMany` (RWX) and what StorageClass would you need on GKE?

---

## Cleanup

PVCs must be deleted manually — they are not removed with a namespace delete in some Kubernetes versions, and the underlying disks incur GCP cost.

```bash
# Delete the StatefulSet first (won't delete PVCs)
kubectl delete statefulset db-store -n storage-lab

# Delete PVCs explicitly
kubectl delete pvc -n storage-lab --all

# Delete remaining pods and other resources
kubectl delete namespace storage-lab
```

Verify the PVs are gone (Released/Deleted) after PVC deletion:

```bash
kubectl get pv | grep storage-lab
```

---

## Key Concepts

| Concept | Description |
|---|---|
| PVC | Request for storage; bound to one PV |
| PV | Actual storage resource (GCE PD, NFS, etc.) |
| StorageClass | Defines how PVs are provisioned (dynamic provisioning) |
| `ReadWriteOnce` | One node can mount read/write |
| `ReadWriteMany` | Many nodes can mount read/write (needs NFS/Filestore) |
| `volumeClaimTemplates` | StatefulSet feature — one PVC per pod replica |
| Reclaim Policy | `Delete` = GCE disk deleted with PVC; `Retain` = disk kept |
