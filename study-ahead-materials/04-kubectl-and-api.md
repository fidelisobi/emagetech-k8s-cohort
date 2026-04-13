# kubectl and the Kubernetes API

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
`kubectl` is your primary interface to a Kubernetes cluster. This section covers the commands you'll use every day, how `kubeconfig` manages cluster connections, how the Kubernetes API is structured into groups and versions, and what happens under the hood when you run a command. Mastering these fundamentals makes everything from debugging to automation much faster.

---

## 🎥 YouTube Videos

### kubectl Basic Commands: Master Your First Kubernetes Operations (Beginner Tutorial)
[![Thumbnail](https://img.youtube.com/vi/h3OTkmuKS3o/0.jpg)](https://www.youtube.com/watch?v=h3OTkmuKS3o)
**Channel:** KodeKloud
> October 2025 — focused 6-minute tutorial on the essential kubectl commands every Kubernetes practitioner needs: get, describe, apply, delete, logs, and exec.

### Important Kubernetes kubectl Commands with Examples in 20 Minutes
[![Thumbnail](https://img.youtube.com/vi/wS277TdV3f8/0.jpg)](https://www.youtube.com/watch?v=wS277TdV3f8)
**Channel:** Cloud Native Simplified
> December 2023 — a practical 20-minute walkthrough of the most-used kubectl commands with concrete examples, covering output formats, label selectors, and namespace flags.

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> Demonstrates practical kubectl workflows in a real cluster — good for understanding the command patterns you'll use throughout the course.

### Day 7/40 — Pod In Kubernetes Explained | Imperative VS Declarative | YAML Tutorial
[![Thumbnail](https://img.youtube.com/vi/_f9ql2Y5Xcc/0.jpg)](https://www.youtube.com/watch?v=_f9ql2Y5Xcc)
**Channel:** Abhishek Veeramalla
> Great for understanding the difference between `kubectl run` (imperative) and `kubectl apply -f` (declarative), and when to use each approach.

---

## 📚 Articles & Documentation

### kubectl Reference
🔗 [Command line tool (kubectl)](https://kubernetes.io/docs/reference/kubectl/)
**Source:** kubernetes.io | **Level:** Beginner
> Official kubectl reference documentation — covers all commands, flags, and output formats. The `--help` flag and this page are your best friends when you forget a command.

### kubectl Cheat Sheet
🔗 [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/quick-reference/)
**Source:** kubernetes.io | **Level:** Beginner
> The official one-page quick reference for the most commonly used kubectl commands. Bookmark this — you'll use it constantly.

### Organizing Cluster Access Using kubeconfig Files
🔗 [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains the kubeconfig file structure: clusters, users, and contexts. Covers how to switch between multiple clusters and manage credentials securely.

### What is a Kubeconfig File & How to Create It
🔗 [What is a Kubeconfig File & How to Create It](https://spacelift.io/blog/kubeconfig)
**Source:** spacelift.io | **Level:** Intermediate
> Practical guide to understanding, creating, and merging kubeconfig files. Includes examples of multi-cluster management and context switching.

### Kubernetes API Overview
🔗 [Kubernetes API](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains the API structure: core group (`v1`), named groups (e.g., `apps/v1`, `networking.k8s.io/v1`), and the alpha → beta → GA stability progression. Critical for understanding `apiVersion` fields.

### API Groups and Versioning
🔗 [API Groups and Versioning](https://kubernetes.io/docs/reference/using-api/#api-groups)
**Source:** kubernetes.io | **Level:** Intermediate
> Reference for all available API groups and how versioning works in Kubernetes, including how deprecated APIs are handled across Kubernetes releases.

---

## 🗝️ Key Concepts to Know Before Class
- **kubeconfig** lives at `~/.kube/config` by default and contains cluster connection info, credentials, and *contexts* (a named pairing of cluster + user + namespace). Use `kubectl config use-context` to switch clusters.
- **API Groups**: Resources belong to groups. Core resources (Pod, Service, Namespace) are in the `""` (empty) core group — `apiVersion: v1`. Others are in named groups like `apps/v1` (Deployment), `batch/v1` (Job), `networking.k8s.io/v1` (Ingress).
- **API stability**: `alpha` (may be deleted without warning), `beta` (stable but may change), `GA/stable` (committed). Always check what version a resource uses.
- **Common kubectl patterns**: `get`, `describe`, `apply`, `delete`, `exec -it`, `logs`, `port-forward`, `rollout status/history/undo`. Use `-o yaml` to see full resource manifests.
- **Dry run**: `kubectl apply --dry-run=client -f file.yaml` validates manifests without applying them — invaluable for CI/CD pipelines.
- The **API request lifecycle**: kubectl → authentication → authorization (RBAC) → admission control → stored in etcd → controller responds.
