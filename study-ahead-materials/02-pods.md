# Pods in Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
The Pod is the fundamental unit of work in Kubernetes — the smallest deployable object you can create and manage. This section covers what a Pod is, how its lifecycle works, how to configure health checks with probes, and how to use specialized container types like init containers and sidecars. Understanding Pods deeply is essential before working with higher-level controllers.

---

## 🎥 YouTube Videos

### Day 7/40 — Pod In Kubernetes Explained | Imperative VS Declarative | YAML Tutorial
[![Thumbnail](https://img.youtube.com/vi/_f9ql2Y5Xcc/0.jpg)](https://www.youtube.com/watch?v=_f9ql2Y5Xcc)
**Channel:** Abhishek Veeramalla (CKA 2024 Series)
> Part of the popular CKA 2024 series — covers pod fundamentals, imperative vs. declarative creation, and YAML manifest structure in a practical format.

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> Hands-on 2024 walkthrough that includes pod creation, inspection, and interaction using `kubectl`. A great visual introduction to how pods work in practice.

### Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]
[![Thumbnail](https://img.youtube.com/vi/X48VuDVv0do/0.jpg)](https://www.youtube.com/watch?v=X48VuDVv0do)
**Channel:** TechWorld with Nana
> The pods section of this comprehensive course covers pod spec anatomy, multi-container pods, and how pods relate to higher-level workload controllers.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> 2024 course that covers pod resource requests and limits, QoS classes, and practical demos of liveness and readiness probes in real cluster environments.

---

## 📚 Articles & Documentation

### Pods
🔗 [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
**Source:** kubernetes.io | **Level:** Beginner
> The official Kubernetes documentation for Pods — covers the spec, lifecycle, networking model, storage, and the difference between single-container and multi-container pods.

### Pod Lifecycle
🔗 [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains pod phases (Pending, Running, Succeeded, Failed, Unknown), container states, and the conditions system that reports pod health to the control plane.

### Configure Liveness, Readiness and Startup Probes
🔗 [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
**Source:** kubernetes.io | **Level:** Intermediate
> Hands-on task guide showing how to configure HTTP, TCP, and exec probes. Includes concrete YAML examples and explains the implications of probe failure.

### Liveness, Readiness, and Startup Probes (Concepts)
🔗 [Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
**Source:** kubernetes.io | **Level:** Intermediate
> Conceptual overview that explains the difference between liveness (restart if unhealthy), readiness (stop traffic if not ready), and startup probes (grace period for slow starts).

### Init Containers
🔗 [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official docs on init containers — specialized containers that run to completion before the main containers start, used for setup tasks, config injection, and dependency checks.

### Resource Management for Pods and Containers
🔗 [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
**Source:** kubernetes.io | **Level:** Intermediate
> Covers CPU/memory requests and limits, QoS classes (Guaranteed, Burstable, BestEffort), and why proper resource configuration matters for cluster stability.

---

## 🗝️ Key Concepts to Know Before Class
- **Pods are ephemeral** — they are designed to be replaced, not repaired. When a pod dies, Kubernetes creates a new one (via controllers) rather than restarting the same pod object.
- **Pod phases**: Pending → Running → Succeeded/Failed. Containers within a pod also have their own states: Waiting, Running, Terminated.
- **Probes**: *Liveness* determines if a container should be restarted. *Readiness* determines if it should receive traffic. *Startup* provides extra time for slow-starting containers before liveness kicks in.
- **Init containers** run sequentially before any app containers start — perfect for setup tasks like downloading configs, running migrations, or waiting for dependencies.
- **Resource requests** are what the scheduler uses to place pods; **limits** are enforced at runtime. The relationship between them determines the pod's QoS class, which affects eviction priority.
- **Labels** are key-value pairs used for selection and grouping. **Annotations** are arbitrary metadata for tools and humans — not used for selection.
