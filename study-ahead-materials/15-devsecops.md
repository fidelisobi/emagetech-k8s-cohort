# DevSecOps for Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
DevSecOps integrates security into every phase of the software development and delivery lifecycle — from code commit (shift-left) to runtime. This section covers the key tools and practices for securing Kubernetes workloads: static analysis (SAST/SCA), software supply chain security (SLSA, Sigstore, SBOM), container image scanning, policy enforcement (OPA/Gatekeeper, Kyverno), runtime threat detection (Falco, Tetragon), and compliance benchmarking (CIS, NIST).

---

## 🎥 YouTube Videos

### What agent to trust with your k8s: Falco, Tetragon or KubeArmor?
[![Thumbnail](https://img.youtube.com/vi/obRMpKsjYPc/0.jpg)](https://www.youtube.com/watch?v=obRMpKsjYPc)
**Channel:** Henrik Rexed
> Published October 2025 — practical comparison of the three main Kubernetes runtime security agents, with live demos showing how each detects threats.

### eBPF-Powered Kubernetes Security: A Complete Guide to Tetragon
[![Thumbnail](https://img.youtube.com/vi/xGcCsIJ5AVU/0.jpg)](https://www.youtube.com/watch?v=xGcCsIJ5AVU)
**Channel:** KodeKloud
> October 2024 deep dive into Cilium Tetragon — how eBPF enables real-time process monitoring, network policy enforcement, and syscall visibility in Kubernetes.

### Falco, Tracee and Tetragon: eBPF Runtime Observability and Security (KubeCon 2024)
[![Thumbnail](https://img.youtube.com/vi/1vRxYRmPDko/0.jpg)](https://www.youtube.com/watch?v=1vRxYRmPDko)
**Channel:** CNCF
> KubeCon 2024 lightning talk comparing Falco, Tracee, and Tetragon — three eBPF-based runtime security tools — explaining their strengths and use cases.

### Deep Dive into Falco: Empower DevSecOps with Real-time Container Security
[![Thumbnail](https://img.youtube.com/vi/MgU-uBmysNE/0.jpg)](https://www.youtube.com/watch?v=MgU-uBmysNE)
**Channel:** Sysdig
> Webinar exploring Falco's threat detection capabilities — rules engine, syscall monitoring, and Kubernetes audit log integration for real-time security alerting.

### Kubernetes Security Tools: DevSecOps Keynote | Falco | Kubescape | Terrascan
[![Thumbnail](https://img.youtube.com/vi/wegwfm1t-kg/0.jpg)](https://www.youtube.com/watch?v=wegwfm1t-kg)
**Channel:** DevSecOps
> Keynote covering the cloud-native security landscape and key Kubernetes security tools — good overview of the tool categories before going deep on any one tool.

---

## 📚 Articles & Documentation

### DevSecOps for Kubernetes
🔗 [DevSecOps for Kubernetes](https://www.wiz.io/academy/container-security/devsecops-for-kubernetes)
**Source:** wiz.io | **Level:** Intermediate
> Comprehensive 2025 guide covering the full DevSecOps lifecycle for Kubernetes — image scanning, RBAC, Network Policies, policy enforcement, and runtime security.

### Kubernetes Policy Comparison: Kyverno vs. OPA/Gatekeeper
🔗 [Kubernetes Policy Comparison: Kyverno vs. OPA/Gatekeeper](https://nirmata.com/2025/02/07/kubernetes-policy-comparison-kyverno-vs-opa-gatekeeper/)
**Source:** nirmata.com | **Level:** Intermediate
> 2025 comparison of the two leading Kubernetes policy engines — Kyverno (Kubernetes-native YAML policies) vs. OPA Gatekeeper (Rego language, more expressive). Helps you choose the right tool.

### Software Supply Chain Security: SBOM, SLSA, Sigstore (2025)
🔗 [Software Supply Chain Security: SBOM, SLSA, Sigstore](https://www.elysiate.com/blog/supply-chain-security-sbom-slsa-sigstore-2025)
**Source:** elysiate.com | **Level:** Intermediate
> End-to-end 2025 guide to supply chain security — from build-time scanning and SBOM generation to image signing with Sigstore/cosign and admission enforcement in Kubernetes.

### Falco Documentation
🔗 [Falco Documentation](https://falco.org/docs/)
**Source:** falco.org | **Level:** Intermediate
> Official Falco docs — the CNCF runtime security project that detects anomalous behavior using eBPF and kernel tracing. Covers rules, macros, output channels, and Kubernetes integration.

### Kyverno Documentation
🔗 [Kyverno Documentation](https://kyverno.io/docs/)
**Source:** kyverno.io | **Level:** Intermediate
> Official Kyverno docs — a Kubernetes-native policy engine that validates, mutates, and generates resources using familiar YAML syntax. No Rego required.

### CIS Kubernetes Benchmark
🔗 [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
**Source:** cisecurity.org | **Level:** Advanced
> The industry-standard security benchmark for Kubernetes clusters — covers API server flags, kubelet configuration, etcd security, network policies, and RBAC. Used by auditors and compliance teams.

---

## 🗝️ Key Concepts to Know Before Class
- **Shift-left security** means finding and fixing vulnerabilities early in development (code/image scanning in CI) rather than at runtime. It's faster and cheaper to fix issues before they reach production.
- **SAST** (Static Application Security Testing) analyzes source code; **SCA** (Software Composition Analysis) finds vulnerabilities in dependencies. Tools: Snyk, Trivy, Grype.
- **SBOM** (Software Bill of Materials) is a formal inventory of all software components in an artifact. **SLSA** (Supply-chain Levels for Software Artifacts) is a framework for build integrity. **Sigstore/cosign** enables keyless container image signing.
- **OPA Gatekeeper** uses Rego policies as admission webhooks to enforce custom rules (e.g., "all images must come from approved registries"). **Kyverno** achieves the same with YAML-based policies.
- **Falco** detects runtime threats using eBPF/kernel module — e.g., "a shell was spawned inside a container" or "unexpected outbound network connection." **Tetragon** (Cilium) goes further with eBPF-native enforcement.
- **CIS Kubernetes Benchmark** and **NIST SP 800-190** are the compliance frameworks used by security teams and auditors to assess cluster hardening. Tools like `kube-bench` automate the assessment.
