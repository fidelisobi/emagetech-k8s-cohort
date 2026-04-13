# Pod Controllers & Deployment Strategies

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Running bare pods in production is an anti-pattern — controllers manage pods, providing self-healing, scaling, and update capabilities. This section covers Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, and CronJobs, plus the deployment strategies (rolling, canary, blue-green, A/B) used in production environments. We also touch on Argo Rollouts for advanced progressive delivery.

---

## 🎥 YouTube Videos

### Kubernetes Deployment Strategies with Demos | Canary | Blue Green | Rolling Update
[![Thumbnail](https://img.youtube.com/vi/0QhUhrWGB9k/0.jpg)](https://www.youtube.com/watch?v=0QhUhrWGB9k)
**Channel:** Abhishek Veeramalla
> Published September 2024 — practical hands-on demos of canary, blue-green, and rolling update strategies in Kubernetes, with real YAML configurations.

### Kubernetes Rolling Updates Explained | Zero-Downtime Deployments Tutorial
[![Thumbnail](https://img.youtube.com/vi/78s-fW-zv6E/0.jpg)](https://www.youtube.com/watch?v=78s-fW-zv6E)
**Channel:** KodeKloud
> October 2025 — focused 5-minute explainer on how rolling updates work, covering maxSurge, maxUnavailable, and zero-downtime deployment patterns.

### Kubernetes StatefulSets Explained: Managing Stateful Applications for Beginners
[![Thumbnail](https://img.youtube.com/vi/XEPwSetgjf4/0.jpg)](https://www.youtube.com/watch?v=XEPwSetgjf4)
**Channel:** KodeKloud
> October 2025 — concise 4-minute breakdown of StatefulSets: stable pod identities, ordered deployment, and when to use StatefulSet vs. Deployment.

### Rolling Update Vs Blue Green Deployment Vs Canary Deployment
[![Thumbnail](https://img.youtube.com/vi/nszj8ZEtl_I/0.jpg)](https://www.youtube.com/watch?v=nszj8ZEtl_I)
**Channel:** Google Cloud Tech
> Explains and demonstrates all major deployment strategies implemented in Kubernetes/GKE — clear visual comparisons of rolling, blue-green, and canary approaches.

### Deployment Strategies in Kubernetes | Rolling | Blue/Green | Canary
[![Thumbnail](https://img.youtube.com/vi/efiMiaFjtn8/0.jpg)](https://www.youtube.com/watch?v=efiMiaFjtn8)
**Channel:** DevOps School
> A focused walkthrough of all four main deployment strategies with YAML configs for each — practical and easy to follow for beginners.

---

## 📚 Articles & Documentation

### Deployments
🔗 [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
**Source:** kubernetes.io | **Level:** Beginner
> The official Deployment documentation — covers creating deployments, rolling updates, rollbacks, scaling, pausing, and the relationship between Deployments and ReplicaSets.

### StatefulSets
🔗 [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official docs for StatefulSets — explains stable network identities, ordered pod management, and PVC templates. Essential reading for running databases on Kubernetes.

### DaemonSet
🔗 [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official docs for DaemonSets — explains how they ensure a pod runs on every (or selected) node. Common use cases include log collectors, monitoring agents, and CNI plugins.

### Jobs
🔗 [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official docs for Kubernetes Jobs — for running batch tasks to completion. Covers parallelism, backoff limits, and job cleanup.

### Understanding Kubernetes Workload Controllers: Deployment vs StatefulSet vs DaemonSet vs Jobs
🔗 [Understanding Kubernetes Workload Controllers](https://semaphore.io/blog/replicaset-statefulset-daemonset-deployments)
**Source:** semaphore.io | **Level:** Beginner
> A well-structured comparison article that explains when to use each controller type with practical examples and decision criteria.

### Argo Rollouts Documentation
🔗 [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
**Source:** argoproj.github.io | **Level:** Advanced
> Official docs for Argo Rollouts — the progressive delivery controller for Kubernetes that enables canary, blue-green, and analysis-driven deployments beyond what native Deployments offer.

---

## 🗝️ Key Concepts to Know Before Class
- **Deployment** is the go-to controller for stateless apps — it manages a ReplicaSet which manages pods. Never manage ReplicaSets directly.
- **StatefulSet** is for stateful apps (databases, queues) — provides stable pod names (`pod-0`, `pod-1`), stable network identities, and ordered start/stop semantics.
- **DaemonSet** ensures one pod per node — used for cluster-level services like Fluentd log shippers, Prometheus node exporters, or CNI plugins.
- **Job/CronJob**: Jobs run a task to completion; CronJobs run Jobs on a schedule. Both support parallelism and retries.
- **Rolling update** (default): gradually replaces old pods with new ones. Controlled by `maxSurge` and `maxUnavailable`.
- **Canary**: send a small % of traffic to the new version, gradually increase. **Blue-green**: run both versions simultaneously, switch traffic at once. These require traffic management tools (Ingress controllers, Argo Rollouts, or Istio).
