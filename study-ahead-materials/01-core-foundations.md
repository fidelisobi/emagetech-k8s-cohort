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

### Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]
[![Thumbnail](https://img.youtube.com/vi/X48VuDVv0do/0.jpg)](https://www.youtube.com/watch?v=X48VuDVv0do)
**Channel:** TechWorld with Nana
> The most-watched Kubernetes beginners course on YouTube. Covers architecture, components, YAML manifests, deployments, services and more with live demos.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> Published in 2024, this comprehensive course walks through deploying real applications on Kubernetes, covering declarative config, controllers, and the full lifecycle.

### Kubernetes Crash Course for Absolute Beginners
[![Thumbnail](https://img.youtube.com/vi/s_o8dwzRlu4/0.jpg)](https://www.youtube.com/watch?v=s_o8dwzRlu4)
**Channel:** TechWorld with Nana
> A focused 1-hour crash course ideal for those who want to understand the essentials before diving into a longer course. Covers all key concepts with clear visuals.

### Kubernetes Course — Full Beginners Tutorial
[![Thumbnail](https://img.youtube.com/vi/d6WC5n9G_sM/0.jpg)](https://www.youtube.com/watch?v=d6WC5n9G_sM)
**Channel:** freeCodeCamp.org
> Full-length tutorial from freeCodeCamp that walks through containerizing applications and deploying to Kubernetes, great for hands-on learners.

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
