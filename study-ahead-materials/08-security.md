# Kubernetes Security

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Security in Kubernetes operates at multiple layers: who can call the API (RBAC), what privileges containers run with (SecurityContext, Pod Security Standards), and what network traffic is allowed (Network Policies). This section covers the essential security primitives every Kubernetes practitioner must understand — from RBAC role design to running containers as non-root and enforcing security policies cluster-wide.

---

## 🎥 YouTube Videos

### Day 23/40 — Kubernetes RBAC Explained — Role Based Access Control
[![Thumbnail](https://img.youtube.com/vi/uGcDt7iNFkE/0.jpg)](https://www.youtube.com/watch?v=uGcDt7iNFkE)
**Channel:** Abhishek Veeramalla (CKA 2024 Series)
> From the 2024 CKA series — a practical breakdown of RBAC including Roles, ClusterRoles, RoleBindings, and real-world access control scenarios.

### RBAC in Kubernetes: Role-Based Access Control Explained | Kubernetes Security Tutorial
[![Thumbnail](https://img.youtube.com/vi/bDkIX0MA8TU/0.jpg)](https://www.youtube.com/watch?v=bDkIX0MA8TU)
**Channel:** KodeKloud
> Published October 2025 — comprehensive RBAC tutorial covering the full authorization model, verbs, resources, and testing permissions with `kubectl auth can-i`.

### Kubernetes RoleBindings & ClusterRoleBindings: Master RBAC Access Control
[![Thumbnail](https://img.youtube.com/vi/AmJBnKHBXHg/0.jpg)](https://www.youtube.com/watch?v=AmJBnKHBXHg)
**Channel:** KodeKloud
> October 2025 tutorial focusing on binding roles to subjects — users, groups, and ServiceAccounts — with real cluster demos.

### Kubernetes RBAC Tutorial: Practical Creation of Role, RoleBinding, ClusterRole & ClusterRoleBinding
[![Thumbnail](https://img.youtube.com/vi/MGCF6slXG0w/0.jpg)](https://www.youtube.com/watch?v=MGCF6slXG0w)
**Channel:** DevOps Pro
> Hands-on creation of all four RBAC object types with practical examples of granting least-privilege access in a real cluster.

---

## 📚 Articles & Documentation

### Role Based Access Control (RBAC)
🔗 [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
**Source:** kubernetes.io | **Level:** Intermediate
> The official and comprehensive RBAC reference — covers all concepts: Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, aggregated roles, and default roles.

### Configure a Security Context for a Pod or Container
🔗 [Configure a Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official task guide showing how to set `runAsUser`, `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, and Linux capabilities on containers and pods.

### Pod Security Standards
🔗 [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
**Source:** kubernetes.io | **Level:** Intermediate
> Defines the three built-in policy levels: **Privileged** (no restrictions), **Baseline** (minimal restrictions), and **Restricted** (hardened). The replacement for deprecated PodSecurityPolicy.

### Network Policies
🔗 [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
**Source:** kubernetes.io | **Level:** Intermediate
> Network Policies function as Kubernetes-native firewalls. This doc explains how to write ingress and egress rules and the default-allow-all behavior when no policies exist.

### Kubernetes RBAC: Role-Based Access Control Explained
🔗 [Kubernetes RBAC: Role-Based Access Control Explained](https://www.gravitee.io/blog/kubernetes-rbac-role-based-access-control)
**Source:** gravitee.io | **Level:** Beginner
> Accessible 2025 guide that explains RBAC concepts with clear diagrams — good first read before tackling the official docs.

### Kubernetes Security Context: A Practical Guide
🔗 [Kubernetes Security Context: A Practical Guide](https://www.tigera.io/learn/guides/kubernetes-security/kubernetes-security-context/)
**Source:** tigera.io | **Level:** Intermediate
> Practical guide to SecurityContext configuration covering both pod-level and container-level settings, with best practices for production hardening.

---

## 🗝️ Key Concepts to Know Before Class
- **RBAC** controls API access. A **Role** grants permissions within a namespace; a **ClusterRole** grants cluster-wide permissions. **RoleBindings** and **ClusterRoleBindings** attach roles to **subjects** (users, groups, ServiceAccounts).
- **ServiceAccounts** are the identity for pods — used by applications to call the Kubernetes API. Always create dedicated ServiceAccounts with minimal permissions rather than using `default`.
- **SecurityContext** controls what a container can do: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, and dropping Linux capabilities are key hardening steps.
- **Pod Security Standards** (PSS) replaced PodSecurityPolicy — enforced via the built-in Pod Security Admission controller using namespace labels.
- **AppArmor and seccomp** provide OS-level syscall filtering and MAC enforcement — applied via annotations or `securityContext.seccompProfile`.
- **Principle of least privilege**: Grant only the permissions required. Audit with `kubectl auth can-i --list` and tools like `kube-bench` and `rbac-lookup`.
