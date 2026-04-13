# ArgoCD & GitOps

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
GitOps is a modern operational model where Git is the single source of truth for all infrastructure and application configuration. ArgoCD is the leading GitOps continuous delivery tool for Kubernetes — it continuously syncs your cluster state to match what's declared in Git. This section covers ArgoCD's architecture, how Applications and AppProjects work, sync strategies, resource hooks, the App of Apps pattern, ApplicationSets for multi-cluster management, and RBAC/SSO integration.

---

## 🎥 YouTube Videos

### ArgoCD Tutorial for Beginners | GitOps CD for Kubernetes
[![Thumbnail](https://img.youtube.com/vi/MeU5_k9ssrs/0.jpg)](https://www.youtube.com/watch?v=MeU5_k9ssrs)
**Channel:** TechWorld with Nana
> The definitive beginner ArgoCD tutorial — covers the full GitOps workflow, ArgoCD architecture, Application syncing, and the benefits of Git as single source of truth. Highly recommended as a first watch.

### Argo CD Tutorial: App of Apps in 8 Minutes
[![Thumbnail](https://img.youtube.com/vi/2pvGL0zqf9o/0.jpg)](https://www.youtube.com/watch?v=2pvGL0zqf9o)
**Channel:** Akuity
> Concise, hands-on demo of the App of Apps pattern in ArgoCD — a powerful GitOps strategy for managing multiple applications declaratively. By an Argo core contributor.

### ArgoCD Tutorial: GitOps Continuous Delivery for Kubernetes | Complete Beginner Guide
[![Thumbnail](https://img.youtube.com/vi/TO-yZ1wHJVQ/0.jpg)](https://www.youtube.com/watch?v=TO-yZ1wHJVQ)
**Channel:** KodeKloud
> October 2025 — focused 8-minute beginner-friendly introduction to ArgoCD and GitOps, covering installation, creating your first Application, and understanding sync policies.

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> This course includes an introduction to GitOps concepts and how ArgoCD integrates as part of a real-world Kubernetes deployment pipeline.

---

## 📚 Articles & Documentation

### Argo CD Getting Started
🔗 [Getting Started — Argo CD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
**Source:** argo-cd.readthedocs.io | **Level:** Beginner
> The official ArgoCD quickstart — installs ArgoCD, creates your first Application, and walks through the sync workflow. Essential first hands-on step.

### Argo CD Concepts: Applications and Projects
🔗 [Argo CD Documentation](https://argo-cd.readthedocs.io/en/stable/)
**Source:** argo-cd.readthedocs.io | **Level:** Intermediate
> The main ArgoCD documentation — covers all concepts: Applications, AppProjects, repositories, clusters, sync policies, health checks, and the Web UI.

### ApplicationSet Controller
🔗 [ApplicationSet Controller](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
**Source:** argo-cd.readthedocs.io | **Level:** Advanced
> Official docs for ApplicationSets — the CRD that generates ArgoCD Applications automatically using generators (Git, List, Cluster, Matrix). Essential for multi-cluster and monorepo patterns.

### Cluster Bootstrapping (App of Apps)
🔗 [Cluster Bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
**Source:** argo-cd.readthedocs.io | **Level:** Intermediate
> The official guide to the App of Apps pattern — a root ArgoCD Application that manages other Applications. The standard approach to bootstrapping a cluster from Git.

### Understanding Argo CD: Kubernetes GitOps Made Simple
🔗 [Understanding Argo CD: Kubernetes GitOps Made Simple](https://codefresh.io/learn/argo-cd/)
**Source:** codefresh.io | **Level:** Beginner
> Comprehensive guide to ArgoCD from Codefresh (Argo's commercial sponsor) — covers architecture, installation methods, Application lifecycle, and GitOps best practices.

### Argo CD Resource Hooks
🔗 [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
**Source:** argo-cd.readthedocs.io | **Level:** Advanced
> Official docs on Argo CD hooks (PreSync, Sync, PostSync, SyncFail, PostDelete) and sync waves — how to control the order of resource deployment and run jobs at lifecycle points.

---

## 🗝️ Key Concepts to Know Before Class
- **GitOps principles**: Git is the single source of truth. All cluster state is declared in Git. Changes happen via pull requests. An automated agent (ArgoCD) continuously reconciles cluster state to match Git.
- **ArgoCD Application**: A CRD that maps a Git source (repo + path/branch) to a destination (cluster + namespace). ArgoCD compares live state vs. desired state and shows drift.
- **Sync policies**: `Manual` (you trigger sync), `Automated` (ArgoCD syncs on every Git change). Automated can optionally `Prune` deleted resources and `SelfHeal` drift.
- **App of Apps**: A root Application whose Git source contains other Application manifests — the standard pattern for bootstrapping entire clusters from a single Git repo.
- **ApplicationSets** automate Application creation at scale — e.g., one ApplicationSet that generates an Application per cluster, per environment, or per directory in a monorepo.
- **Sync waves** (via `argocd.argoproj.io/sync-wave` annotation) control the order resources are applied. **Hooks** run Jobs at specific sync phases (PreSync, PostSync, etc.).
