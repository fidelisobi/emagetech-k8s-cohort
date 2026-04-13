# Core Foundations of Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
This section introduces Kubernetes — what it is, why it exists, and how it works conceptually. You'll learn how Kubernetes fits into the cloud-native ecosystem (CNCF), the key principles behind declarative configuration, and how the Kubernetes API and control loops keep your cluster in the desired state. These fundamentals underpin everything else in the course.

---

## 🎥 YouTube Videos

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> A crisp, hands-on 2024 overview of what Kubernetes is and the problems it solves — perfect first watch. Covers containers, pods, nodes, and basic architecture.

### Kubernetes Architecture Simplified | K8s Explained in 10 Minutes | KodeKloud
[![Thumbnail](https://img.youtube.com/vi/8C_SCDbUJTg/0.jpg)](https://www.youtube.com/watch?v=8C_SCDbUJTg)
**Channel:** KodeKloud
> A concise 10-minute explainer using a ships analogy that makes the control plane and worker node architecture immediately intuitive — great visual foundation.

### Day 7/40 — Pod In Kubernetes Explained | Imperative VS Declarative | YAML Tutorial
[![Thumbnail](https://img.youtube.com/vi/_f9ql2Y5Xcc/0.jpg)](https://www.youtube.com/watch?v=_f9ql2Y5Xcc)
**Channel:** Abhishek Veeramalla (CKA 2024 Series)
> From the 2024 CKA series — covers pod fundamentals, imperative vs. declarative creation, and YAML manifest structure. Directly relevant to core Kubernetes concepts.

### Kubernetes Control Plane Explained: API Server, Scheduler, Controller Manager & etcd
[![Thumbnail](https://img.youtube.com/vi/K9-6wgc6Ov8/0.jpg)](https://www.youtube.com/watch?v=K9-6wgc6Ov8)
**Channel:** Cloud Native Simplified
> Comprehensive 2025 breakdown of the control plane "brain" — how each component coordinates to schedule and reconcile workloads across the cluster.

---

## 📚 Articles & Documentation

### What is Kubernetes?
🔗 [What is Kubernetes?](https://kubernetes.io/docs/concepts/overview/)
**Source:** kubernetes.io | **Level:** Beginner
> The official Kubernetes documentation introduction — explains the history, use cases, and high-level architecture of Kubernetes. Start here.

### Objects In Kubernetes
🔗 [Objects In Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
**Source:** kubernetes.io | **Level:** Beginner
> Explains the manifest anatomy: `apiVersion`, `kind`, `metadata`, `spec`, and `status` fields. Covers how Kubernetes uses the spec/status pattern to maintain desired state.

### Declarative Management of Kubernetes Objects Using Configuration Files
🔗 [Declarative Management of Kubernetes Objects](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
**Source:** kubernetes.io | **Level:** Intermediate
> Practical guide to managing objects declaratively with `kubectl apply`. Demonstrates the difference between imperative and declarative approaches.

### Controllers — The Kubernetes Control Loop
🔗 [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official docs on controllers and reconciliation loops — explains how Kubernetes constantly watches state and drives the cluster toward the desired configuration.

### Kubernetes & Container Orchestration: The 2025 Starter Guide
🔗 [Kubernetes & Container Orchestration: The 2025 Starter Guide](https://anynines.com/blog/intro-kubernetes-container-orchestration/)
**Source:** anynines.com | **Level:** Beginner
> A well-written 2025 primer on what container orchestration is, why Kubernetes became the standard, and how it fits into modern cloud-native infrastructure.

### CNCF Cloud Native Landscape
🔗 [CNCF Cloud Native Landscape](https://landscape.cncf.io/)
**Source:** cncf.io | **Level:** Beginner
> The interactive CNCF landscape map showing where Kubernetes fits in the broader cloud-native ecosystem. Essential reference for understanding the project ecosystem.

---

## 🗝️ Key Concepts to Know Before Class
- **Kubernetes** is an open-source container orchestration system originally developed by Google, now maintained by the CNCF. It automates deployment, scaling, and management of containerized apps.
- **Declarative config** means you describe *what* you want (desired state) in YAML manifests, and Kubernetes figures out *how* to get there — contrasted with imperative commands.
- **Manifest anatomy**: Every Kubernetes object has `apiVersion` (which API version/group), `kind` (resource type), `metadata` (name, labels, namespace), `spec` (desired state), and `status` (current state managed by the system).
- **Control loop / reconciliation**: Controllers continuously compare actual state vs. desired state and take corrective action — this is the heartbeat of Kubernetes.
- **CNCF** (Cloud Native Computing Foundation) is the vendor-neutral home of Kubernetes and 100+ other cloud-native projects like Prometheus, Envoy, and Helm.
