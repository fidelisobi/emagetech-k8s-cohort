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

### Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]
[![Thumbnail](https://img.youtube.com/vi/X48VuDVv0do/0.jpg)](https://www.youtube.com/watch?v=X48VuDVv0do)
**Channel:** TechWorld with Nana
> Includes troubleshooting sections throughout — covers using `kubectl logs`, `kubectl describe`, `kubectl exec`, and reading Events to diagnose pod issues.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> The 2024 edition dedicates significant content to debugging Kubernetes workloads — includes `kubectl debug`, ephemeral containers, and cluster-level diagnostics.

### Kubernetes Architecture Explained | Control Plane Components
[![Thumbnail](https://img.youtube.com/vi/5zImYn0isPk/0.jpg)](https://www.youtube.com/watch?v=5zImYn0isPk)
**Channel:** DevOps Shack
> Understanding architecture is prerequisite to troubleshooting — this video helps you know where to look when things go wrong at the cluster level (e.g., scheduler issues, etcd connectivity).

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
