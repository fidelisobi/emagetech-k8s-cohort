# Advanced Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Once you're comfortable with the basics, Kubernetes has a rich set of advanced features for extending the platform and optimizing workload placement and scaling. This section covers Custom Resource Definitions (CRDs) and the Operator pattern, admission controllers and webhooks, advanced scheduling with node affinity and taints/tolerations, horizontal and vertical autoscaling, and next-generation node provisioning with Karpenter.

---

## 🎥 YouTube Videos

### Kubernetes Custom Resources Explained (CRDs, Controllers, & Operators)
[![Thumbnail](https://img.youtube.com/vi/xlBMpLNaPlg/0.jpg)](https://www.youtube.com/watch?v=xlBMpLNaPlg)
**Channel:** Mischa van den Burg
> Published February 2026 — clear explanation of the difference between CRDs, custom resources, controllers, and operators, with practical examples.

### Kubernetes Operators Explained: Building Self-Healing & Resilient Clusters with CRDs
[![Thumbnail](https://img.youtube.com/vi/wfSSExyX6Wo/0.jpg)](https://www.youtube.com/watch?v=wfSSExyX6Wo)
**Channel:** That DevOps Guy
> Published January 2026 — deep dive into how operators use reconciliation loops and CRDs to model application-specific state in Kubernetes.

### Day 49 — Custom Resource Definition (CRD, CR) Kubernetes (explained with Demo)
[![Thumbnail](https://img.youtube.com/vi/3huz7lRzUQo/0.jpg)](https://www.youtube.com/watch?v=3huz7lRzUQo)
**Channel:** Abhishek Veeramalla (CKA 2025 Series)
> Hands-on demo of creating and using CRDs in a real cluster from the 2025 CKA series — includes a practical controller walkthrough.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> The advanced sections of this 2024 course cover HPA, node affinity, taints and tolerations, and resource quotas with hands-on labs.

### What The Heck Are Kubernetes Resources, CRs, CRDs, Operators, etc.?
[![Thumbnail](https://img.youtube.com/vi/aM2Y9m2Kazk/0.jpg)](https://www.youtube.com/watch?v=aM2Y9m2Kazk)
**Channel:** Viktor Farcic (DevOps Toolkit)
> A conceptual video that demystifies the often-confused Kubernetes extension primitives — great for building a mental model before hands-on work.

---

## 📚 Articles & Documentation

### Custom Resources
🔗 [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
**Source:** kubernetes.io | **Level:** Advanced
> Official docs on extending the Kubernetes API with CRDs — covers when to use CRDs vs. API aggregation, and the custom controller/operator pattern.

### Operator Pattern
🔗 [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
**Source:** kubernetes.io | **Level:** Advanced
> Explains the Operator pattern: encoding operational knowledge into a controller. Links to OperatorHub and the Operator SDK.

### Autoscaling Workloads
🔗 [Autoscaling Workloads](https://kubernetes.io/docs/concepts/workloads/autoscaling/)
**Source:** kubernetes.io | **Level:** Intermediate
> Overview of Kubernetes autoscaling: HPA (scale pods horizontally based on metrics), VPA (adjust resource requests automatically), and KEDA for event-driven scaling.

### Assigning Pods to Nodes
🔗 [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
**Source:** kubernetes.io | **Level:** Intermediate
> Covers nodeSelector, node affinity/anti-affinity, pod affinity/anti-affinity, and topology spread constraints for controlling pod placement.

### Taints and Tolerations
🔗 [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains how taints repel pods from nodes and how tolerations allow specific pods to be scheduled on tainted nodes — the inverse of node affinity.

### Karpenter Documentation
🔗 [Karpenter Documentation](https://karpenter.sh/docs/)
**Source:** karpenter.sh | **Level:** Advanced
> Official Karpenter docs — the AWS-originated open-source node provisioner that intelligently launches the right compute for pending pods, significantly improving cluster efficiency over the Cluster Autoscaler.

---

## 🗝️ Key Concepts to Know Before Class
- **CRDs** (Custom Resource Definitions) extend the Kubernetes API with new resource types. Once created, you can manage custom resources with `kubectl` just like native resources.
- **Operators** = CRDs + custom controllers. They encode operational knowledge (backup, failover, upgrades) into Kubernetes-native automation. OperatorHub.io lists 300+ production operators.
- **Admission Controllers** intercept API requests after authentication but before persistence. **Mutating** webhooks modify objects; **Validating** webhooks reject non-compliant ones. Tools like OPA Gatekeeper and Kyverno use this mechanism.
- **HPA** scales pod replicas based on CPU, memory, or custom metrics. **VPA** adjusts CPU/memory requests on running pods. They should not be used together on the same metric.
- **Node Affinity** is preference-based scheduling (`requiredDuringScheduling` vs. `preferredDuringScheduling`). **Taints/Tolerations** are used to dedicate nodes to specific workloads (e.g., GPU nodes, spot instances).
- **Topology Spread Constraints** distribute pods evenly across failure domains (zones, nodes) for high availability.
