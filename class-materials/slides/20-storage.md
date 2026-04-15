# Session 20 — Storage

---

## Storage Overview

Containers have an ephemeral filesystem — data is lost when the container restarts. Kubernetes provides volume abstractions to persist data beyond the container lifecycle.

**Key Concepts:**
- Volumes — directory accessible to containers in a Pod
- Persistent Volumes (PV) — cluster-level storage resource
- Persistent Volume Claims (PVC) — user's request for storage
- StorageClass — defines how storage is dynamically provisioned

---

## PV / PVC Relationship

- **PersistentVolume (PV)** — a piece of storage provisioned by an admin or dynamically via StorageClass
- **PersistentVolumeClaim (PVC)** — a request for storage by a user/pod
- PVC binds to a PV that satisfies its requirements (size, access mode, StorageClass)
- Pods reference PVCs, not PVs directly

**Analogy:** Think of a hotel. The room is the PV (the physical resource), the reservation is the PVC (your claim on it), and the hotel category (standard/suite) is the StorageClass — it defines what kind of room you get and how it is provisioned.

---

## Storage Lifecycle

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ StorageClass │────►│ PVC created  │────►│  PV bound    │────►│ Pod mounts   │
│ (template)   │     │ (request)    │     │ (provisioned)│     │ (uses volume)│
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

**Provisioning:**
- **Static** — admin pre-creates PVs, PVCs bind to matching PVs
- **Dynamic** — PVC references a StorageClass, PV is created automatically

**Binding:**
- PVC binds to a PV that matches its requirements
- One-to-one binding — a PV can only be bound to one PVC

**Using:**
- Pod mounts the PVC as a volume

**Reclaiming:**
- What happens to the PV when the PVC is deleted
  - **Retain** — PV is kept, data preserved (manual cleanup)
  - **Delete** — PV and underlying storage are deleted

---

## Dynamic Provisioning with StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io    # GKE
parameters:
  type: pd-ssd
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Volume Binding Modes:**
- `Immediate` — PV provisioned immediately when PVC is created
- `WaitForFirstConsumer` — PV provisioned only when a Pod using the PVC is scheduled (preferred — respects topology)

---

## PVC YAML Example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
```

Once created, Kubernetes will look for a PV (or dynamically provision one) that satisfies the request. The PVC moves from `Pending` to `Bound` when a matching PV is found.

---

## Mounting a PVC in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: nginx:stable
      volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data   # references the PVC above
```

The container reads and writes to `/usr/share/nginx/html`, which is backed by the persistent volume. Data survives container restarts.

---

## Access Modes

| Mode | Abbreviation | Description |
|------|-------------|-------------|
| ReadWriteOnce | RWO | Mounted read-write by a single node |
| ReadOnlyMany | ROX | Mounted read-only by many nodes |
| ReadWriteMany | RWX | Mounted read-write by many nodes |
| ReadWriteOncePod | RWOP | Mounted read-write by a single pod |

**Cloud Support:**
- Cloud environments typically support RWO and ROX
- RWX requires specific storage backends (NFS, Filestore, EFS, Azure Files)

---

## Cloud Provider Storage

| Provider | Block Storage | File Storage |
|----------|--------------|--------------|
| **GCP** | GCE Persistent Disk (pd-standard, pd-ssd) | Filestore (NFS) |
| **AWS** | EBS (gp3, io2) | EFS (NFS) |
| **Azure** | Azure Disk (Standard, Premium SSD) | Azure Files (SMB/NFS) |

---

## Volume Expansion, Snapshots & Cloning

**Volume Expansion:**
- StorageClass must have `allowVolumeExpansion: true`
- Edit PVC to increase `spec.resources.requests.storage`
- File system expansion may require pod restart

**Volume Snapshots:**
- Create point-in-time copies of PVs
- VolumeSnapshot, VolumeSnapshotClass, VolumeSnapshotContent CRDs
- Requires CSI driver support

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: app-data-snapshot
spec:
  volumeSnapshotClassName: csi-pd-vsc   # VolumeSnapshotClass from your CSI driver
  source:
    persistentVolumeClaimName: app-data
```

**Volume Cloning:**
- Create a new PVC from an existing PVC
- `dataSource` field in the new PVC references the source PVC

---

## StatefulSet + PVC Patterns

- StatefulSets use `volumeClaimTemplates` — each pod gets its own PVC
- PVCs are named: `<template-name>-<statefulset-name>-<ordinal>`
- When a StatefulSet pod is deleted and recreated, it reattaches to the same PVC
- PVCs are NOT deleted when the StatefulSet is scaled down (data is preserved)
- Manual cleanup required: `kubectl delete pvc <name>`

---

## Key Takeaways

- Pods should not rely on local container storage for anything that must survive a restart — use PVCs
- StorageClass is the template; PVC is the request; PV is the fulfillment
- Use `WaitForFirstConsumer` binding mode in multi-zone clusters to avoid cross-zone volume attachment errors
- The `Recycle` reclaim policy was removed entirely in Kubernetes v1.11 — only `Retain` and `Delete` are valid
- RWX access requires a file-based backend (NFS, Filestore, EFS, Azure Files) — block storage (EBS, GCE PD, Azure Disk) is RWO only
- VolumeSnapshots require a CSI driver and the snapshot CRDs to be installed separately
- StatefulSet PVCs outlive their pods by design — delete them explicitly when no longer needed

---

## Review Questions

### Beginner

1. What is the difference between a PersistentVolume (PV) and a PersistentVolumeClaim (PVC)? Which one does a Pod reference directly?
2. What does a StorageClass define, and how does it relate to dynamic provisioning?
3. What is the difference between the `Retain` and `Delete` reclaim policies, and when would you choose each?
4. Which access mode would you use if you need multiple pods across different nodes to read and write to the same volume simultaneously?
5. Why is `WaitForFirstConsumer` the preferred volume binding mode in multi-zone clusters?

### Intermediate

1. A StatefulSet named `db` has 3 replicas and uses a `volumeClaimTemplate` named `data`. You scale the StatefulSet down to 1 replica. What happens to the PVCs for the two removed pods, and what action must you take if you want to fully clean up the storage?
2. A developer asks you to expand a PVC from 10Gi to 50Gi. Walk through what conditions must be true for this to succeed and what steps are involved, including any potential impact on a running Pod.
