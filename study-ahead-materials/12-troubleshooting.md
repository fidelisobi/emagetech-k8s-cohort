# Kubernetes Troubleshooting

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Kubernetes troubleshooting is a core skill — production incidents are inevitable, and knowing how to quickly diagnose and resolve them separates junior from senior practitioners. This section covers the essential `kubectl` debugging commands, the methodology for systematic problem diagnosis, and deep dives into the most common failure modes: `CrashLoopBackOff`, `Pending` pods, `OOMKilled`, `ImagePullBackOff`, and more.

---

## 🎥 YouTube Videos

### Day-2 | Kubernetes Troubleshooting | CrashLoopBackOff with 3 Real-Time Scenarios including OOMKilled
[![Thumbnail](https://img.youtube.com/vi/aEPIlQBWBGQ/0.jpg)](https://www.youtube.com/watch?v=aEPIlQBWBGQ)
**Channel:** Abhishek Veeramalla
> Published April 2024 — three realistic CrashLoopBackOff scenarios with root cause analysis and fixes, including OOMKilled. Real-world problem-solving approach.

### 4 Simple Commands To Troubleshoot Kubernetes (2024)
[![Thumbnail](https://img.youtube.com/vi/1RSlP-mQrP0/0.jpg)](https://www.youtube.com/watch?v=1RSlP-mQrP0)
**Channel:** That DevOps Guy
> June 2024 — a quick 3-minute practical guide to the four kubectl commands that solve the majority of Kubernetes debugging scenarios — essential quick reference.

### Kubernetes Architecture Explained | Control Plane Components
[![Thumbnail](https://img.youtube.com/vi/5zImYn0isPk/0.jpg)](https://www.youtube.com/watch?v=5zImYn0isPk)
**Channel:** DevOps Shack
> Understanding architecture is prerequisite to troubleshooting — this video helps you know where to look when things go wrong at the cluster level (e.g., scheduler issues, etcd connectivity).

### Day 18/40 — Kubernetes Health Probes Explained | Liveness vs Readiness Probes
[![Thumbnail](https://img.youtube.com/vi/x2e6pIBLKzw/0.jpg)](https://www.youtube.com/watch?v=x2e6pIBLKzw)
**Channel:** Abhishek Veeramalla (CKA 2024 Series)
> July 2024 — 28-minute hands-on session on health probes, covering how misconfigured probes cause CrashLoopBackOff and how to diagnose and fix them.

---

## 📚 Articles & Documentation

### Troubleshoot Applications
🔗 [Troubleshoot Applications](https://kubernetes.io/docs/tasks/debug/debug-application/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official Kubernetes troubleshooting guide — covers debugging pods, replication controllers, and services with step-by-step kubectl commands and diagnostic approaches.

### Troubleshoot and Fix Kubernetes CrashLoopBackOff Status
🔗 [Troubleshoot and Fix Kubernetes CrashLoopBackOff Status](https://komodor.com/learn/how-to-fix-crashloopbackoff-kubernetes-error/)
**Source:** komodor.com | **Level:** Intermediate
> Comprehensive 2026 guide to diagnosing CrashLoopBackOff — covers all root causes (config errors, dependency failures, OOMKilled, liveness probe failures) with fix instructions.

### Understanding Kubernetes CrashLoopBackOff & How to Fix It
🔗 [Understanding Kubernetes CrashLoopBackOff & How to Fix It](https://www.groundcover.com/kubernetes-troubleshooting/crashloopbackoff)
**Source:** groundcover.com | **Level:** Intermediate
> Clear, diagram-heavy guide to the CrashLoopBackOff error — explains the exponential backoff timing, how to read exit codes, and systematic debugging steps.

### Kubernetes CrashLoopBackOff Root-Cause Flowchart & Quick Fixes
🔗 [Kubernetes CrashLoopBackOff Root-Cause Flowchart & Quick Fixes](https://www.netdata.cloud/academy/kubernetes-crash-loop-backoff/)
**Source:** netdata.cloud | **Level:** Intermediate
> Includes a diagnostic flowchart for CrashLoopBackOff, exit code reference (Exit 1, 137/OOMKilled, 139/segfault), and quick-fix commands for each scenario.

### Troubleshoot CrashLoopBackOff Events (GKE)
🔗 [Troubleshoot CrashLoopBackOff Events](https://docs.cloud.google.com/kubernetes-engine/docs/troubleshooting/crashloopbackoff-events)
**Source:** cloud.google.com | **Level:** Intermediate
> GKE-specific but broadly applicable guide to diagnosing CrashLoopBackOff — covers resource exhaustion, app misconfigurations, and liveness probe failures with concrete kubectl commands.

### Debug Running Pods
🔗 [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
**Source:** kubernetes.io | **Level:** Advanced
> Covers advanced debugging techniques: `kubectl debug` with ephemeral containers, copying pods for debugging, and attaching to running containers.

---

## 🗝️ Key Concepts to Know Before Class
- **Debugging toolkit**: `kubectl describe pod <name>` (Events section is gold), `kubectl logs <pod> --previous` (crashed container logs), `kubectl exec -it <pod> -- sh` (get a shell), `kubectl get events --sort-by=.lastTimestamp`.
- **CrashLoopBackOff** means the container is repeatedly crashing and Kubernetes is backing off restarts. Check: application logs (`kubectl logs --previous`), liveness probe config, environment variables, and resource limits.
- **Pending pods** — check: node resources (CPU/memory), node taints/tolerations, PVC binding status, image pull secrets, and scheduler logs.
- **OOMKilled** (exit code 137) means the container exceeded its memory limit. Fix: increase memory limit, optimize application memory usage, or check for memory leaks.
- **ImagePullBackOff** — check: image name/tag spelling, registry credentials (`imagePullSecrets`), and network connectivity to the registry.
- **Systematic methodology**: Start at the pod level → check container logs and events → check node resources → check network policies → check RBAC → escalate to control plane logs.
