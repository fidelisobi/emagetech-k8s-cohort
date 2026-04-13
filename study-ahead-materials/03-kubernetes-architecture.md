# Kubernetes Architecture

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
A Kubernetes cluster is made up of a **control plane** (the brain) and **worker nodes** (the muscle). Understanding how the API server, etcd, scheduler, controller manager, kubelet, and kube-proxy interact is critical for troubleshooting, scaling, and operating clusters in production. This section demystifies how a pod request flows from `kubectl apply` all the way to a running container.

---

## 🎥 YouTube Videos

### Kubernetes Architecture Explained | Control Plane Components (Part 01)
[![Thumbnail](https://img.youtube.com/vi/5zImYn0isPk/0.jpg)](https://www.youtube.com/watch?v=5zImYn0isPk)
**Channel:** DevOps Shack
> Published in 2026, this video clearly explains each control plane component — API server, etcd, scheduler, and controller manager — with diagrams and worked examples.

### Kubernetes Control Plane Explained: API Server, Scheduler, Controller Manager & etcd
[![Thumbnail](https://img.youtube.com/vi/K9-6wgc6Ov8/0.jpg)](https://www.youtube.com/watch?v=K9-6wgc6Ov8)
**Channel:** Cloud Native Simplified
> Comprehensive 2025 breakdown of the control plane "brain" — how each component coordinates to schedule and reconcile workloads across the cluster.

### Kubernetes Architecture Simplified | K8s Explained in 10 Minutes | KodeKloud
[![Thumbnail](https://img.youtube.com/vi/8C_SCDbUJTg/0.jpg)](https://www.youtube.com/watch?v=8C_SCDbUJTg)
**Channel:** KodeKloud
> A crisp 10-minute visual explainer using an analogy that makes control plane and worker node roles immediately clear — ideal for building your mental model.

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> Hands-on 2024 walkthrough that explores node components (kubelet, kube-proxy, container runtime) and how they interact with the control plane in a real cluster.

---

## 📚 Articles & Documentation

### Cluster Architecture
🔗 [Cluster Architecture](https://kubernetes.io/docs/concepts/architecture/)
**Source:** kubernetes.io | **Level:** Beginner
> The official overview of the full Kubernetes cluster architecture — explains the control plane, node components, and how they interact. The definitive reference.

### Kubernetes Components
🔗 [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
**Source:** kubernetes.io | **Level:** Beginner
> Concise overview of every component in a Kubernetes cluster: kube-apiserver, etcd, kube-scheduler, kube-controller-manager, kubelet, kube-proxy, and container runtime.

### Kubernetes Control Plane: Ultimate Guide (2024)
🔗 [Kubernetes Control Plane: Ultimate Guide](https://www.plural.sh/blog/kubernetes-control-plane-architecture/)
**Source:** plural.sh | **Level:** Intermediate
> In-depth 2024 guide covering the control plane architecture, including the cloud controller manager, leader election for HA, and how each component's responsibilities are separated.

### etcd Documentation
🔗 [etcd Documentation](https://etcd.io/docs/)
**Source:** etcd.io | **Level:** Intermediate
> Official etcd docs — the distributed key-value store that backs all Kubernetes state. Understanding etcd is critical for cluster backup and disaster recovery.

### Network Plugins (CNI)
🔗 [Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains how CNI plugins integrate with kubelet to provide pod networking, and what requirements a CNI plugin must meet to work with Kubernetes.

### CoreDNS
🔗 [CoreDNS](https://coredns.io/manual/toc/)
**Source:** coredns.io | **Level:** Intermediate
> Documentation for CoreDNS — the default DNS server in Kubernetes clusters. Understanding how service discovery works via DNS is fundamental to cluster networking.

---

## 🗝️ Key Concepts to Know Before Class
- **Control Plane components**: `kube-apiserver` (the front door — all communication goes through it), `etcd` (the source of truth — all state is stored here), `kube-scheduler` (assigns pods to nodes), `kube-controller-manager` (runs reconciliation loops for deployments, endpoints, nodes, etc.).
- **Worker Node components**: `kubelet` (agent on every node that runs pods as instructed by the API server), `kube-proxy` (handles network rules for service traffic), and a **container runtime** (containerd, CRI-O) that actually runs containers.
- **CRI** (Container Runtime Interface): The standard API between kubelet and container runtimes — why Docker was replaced by containerd.
- **CoreDNS** provides in-cluster DNS, enabling pods to find services by name (e.g., `my-service.my-namespace.svc.cluster.local`).
- **Namespaces** provide soft multi-tenancy — they scope resources but don't provide strong isolation (that requires Network Policies and RBAC).
- For **HA clusters**, the control plane runs multiple replicas of the API server (load-balanced) and uses leader election for the scheduler and controller manager.
