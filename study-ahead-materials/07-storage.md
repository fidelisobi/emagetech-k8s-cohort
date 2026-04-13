# Storage in Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Kubernetes provides a rich storage model that separates the *what* (PersistentVolumeClaims) from the *how* (PersistentVolumes and StorageClasses). This section covers static and dynamic volume provisioning, ConfigMaps and Secrets for configuration injection, and advanced patterns like the DownwardAPI and projected volumes. Getting storage right is critical for running stateful applications reliably.

---

## 🎥 YouTube Videos

### Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]
[![Thumbnail](https://img.youtube.com/vi/X48VuDVv0do/0.jpg)](https://www.youtube.com/watch?v=X48VuDVv0do)
**Channel:** TechWorld with Nana
> Covers Kubernetes volumes, PersistentVolumes, PVCs, and ConfigMaps/Secrets in depth, with practical YAML examples you can follow along with.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> This 2024 course includes hands-on storage labs covering StorageClass dynamic provisioning, PVCs, and secret injection via environment variables and volume mounts.

### Day 7/40 — Pod In Kubernetes Explained | Imperative VS Declarative | YAML Tutorial
[![Thumbnail](https://img.youtube.com/vi/_f9ql2Y5Xcc/0.jpg)](https://www.youtube.com/watch?v=_f9ql2Y5Xcc)
**Channel:** Abhishek Veeramalla
> Includes a walkthrough of ConfigMaps and Secrets — how to create them, mount them as volumes, and inject them as environment variables into pods.

### Kubernetes Crash Course for Absolute Beginners
[![Thumbnail](https://img.youtube.com/vi/s_o8dwzRlu4/0.jpg)](https://www.youtube.com/watch?v=s_o8dwzRlu4)
**Channel:** TechWorld with Nana
> Covers the storage fundamentals including ConfigMaps and Secrets from a beginner perspective, with clear visuals explaining how volume mounts work.

---

## 📚 Articles & Documentation

### Persistent Volumes
🔗 [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
**Source:** kubernetes.io | **Level:** Intermediate
> The definitive guide to PersistentVolumes and PersistentVolumeClaims — covers access modes, reclaim policies, binding, StorageClasses, and dynamic provisioning.

### Storage Classes
🔗 [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains how StorageClasses enable dynamic PV provisioning, including provisioner configurations for AWS EBS, GCE PD, Azure Disk, and NFS.

### ConfigMaps
🔗 [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
**Source:** kubernetes.io | **Level:** Beginner
> Official docs for ConfigMaps — how to create them, reference them as environment variables, and mount them as files inside containers.

### Secrets
🔗 [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official Secrets documentation — covers secret types, how to consume secrets safely, encryption at rest, and important security considerations.

### Kubernetes Persistent Volumes — Tutorial and Examples
🔗 [Kubernetes Persistent Volumes — Tutorial and Examples](https://spacelift.io/blog/kubernetes-persistent-volumes)
**Source:** spacelift.io | **Level:** Beginner
> Practical 2025 tutorial showing how to create PVs, PVCs, and bind them to pods, with worked examples and common pitfalls explained.

### Volumes
🔗 [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
**Source:** kubernetes.io | **Level:** Intermediate
> Overview of all Kubernetes volume types including `emptyDir`, `hostPath`, `configMap`, `secret`, `downwardAPI`, `projected`, and `persistentVolumeClaim`.

---

## 🗝️ Key Concepts to Know Before Class
- **PersistentVolume (PV)**: Cluster-wide storage resource provisioned by an admin or dynamically by a StorageClass. Independent of any pod lifecycle.
- **PersistentVolumeClaim (PVC)**: A user's request for storage — specifies size and access mode. The cluster binds the PVC to a suitable PV.
- **StorageClass** enables *dynamic provisioning* — when a PVC is created, Kubernetes automatically creates a PV from the cloud provider or storage backend.
- **Access modes**: `ReadWriteOnce` (one node), `ReadOnlyMany` (many nodes, read-only), `ReadWriteMany` (many nodes, read-write). Not all backends support all modes.
- **ConfigMaps** store non-sensitive configuration data. **Secrets** store sensitive data (base64-encoded, not encrypted by default — use encryption at rest and external secret managers in production).
- **DownwardAPI** allows pods to consume information about themselves (pod name, namespace, labels, resource limits) as environment variables or volume files.
- **Projected volumes** combine multiple volume sources (secret, configmap, serviceAccountToken, downwardAPI) into a single mount point.
