# Kubernetes January 2026 Cohort — Study-Ahead Materials

Welcome to the **Kubernetes January 2026 Cohort** study-ahead resource library. These materials are designed to help you arrive at each class session with foundational knowledge, so we can spend class time on hands-on labs, deep dives, and real-world scenarios rather than introductory content.

---

## 📖 About This Course

This is a professional Kubernetes training program covering the full spectrum of Kubernetes — from core concepts and architecture to advanced topics like service meshes, GitOps, and DevSecOps. The course is designed for engineers who will be operating Kubernetes in production environments.

**Prerequisites:** Familiarity with Linux command line, basic Docker/containers knowledge, and general networking concepts.

---

## 🗺️ How to Use These Materials

1. **Before each session**: Read the corresponding study-ahead document and watch at least 2-3 of the recommended videos.
2. **Focus on Key Concepts**: Each document ends with a "Key Concepts to Know Before Class" section — make sure you can explain each bullet point.
3. **Don't aim for mastery**: The goal is *familiarity*, not expertise. You'll build expertise during the hands-on labs in class.
4. **Use the official docs**: The Kubernetes documentation at [kubernetes.io/docs](https://kubernetes.io/docs) is excellent. Many links go there — bookmark it.
5. **Take notes**: Write down questions as you study. Bring them to class!

---

## 📚 Module Index

| # | Module | Topics |
|---|--------|--------|
| 01 | [Core Foundations](./01-core-foundations.md) | Kubernetes overview, CNCF, container orchestration, Kubernetes API, manifest anatomy, declarative config, control loops |
| 02 | [Pods](./02-pods.md) | Pod definition, ephemerality, lifecycle phases, liveness/readiness/startup probes, init/sidecar/ephemeral containers, resource requests/limits/QoS, labels/selectors/annotations |
| 03 | [Kubernetes Architecture](./03-kubernetes-architecture.md) | Control plane (API server, etcd, scheduler, controller manager), worker nodes (kubelet, kube-proxy, CRI), CoreDNS, namespaces, cluster HA |
| 04 | [kubectl and the API](./04-kubectl-and-api.md) | kubectl commands, kubeconfig, API groups/versions (alpha/beta/GA), request lifecycle |
| 05 | [Pod Controllers](./05-pod-controllers.md) | Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs, rolling/canary/blue-green/A-B strategies, Argo Rollouts |
| 06 | [Networking](./06-networking.md) | Kubernetes networking model, CNI, Services (ClusterIP/NodePort/LoadBalancer), Ingress, Network Policies, CoreDNS, EndpointSlices, kube-proxy |
| 07 | [Storage](./07-storage.md) | Persistent Volumes, PVCs, StorageClass, dynamic provisioning, ConfigMaps, Secrets, DownwardAPI, projected volumes |
| 08 | [Security](./08-security.md) | RBAC (Roles, ClusterRoles, RoleBindings), SecurityContext, Pod Security Standards, Network Policies, AppArmor/seccomp |
| 09 | [Advanced Kubernetes](./09-advanced-kubernetes.md) | CRDs, Operators, admission controllers, webhooks, node affinity, taints/tolerations, HPA, VPA, Cluster Autoscaler, Karpenter, topology spread constraints |
| 10 | [Helm](./10-helm.md) | Helm overview, chart structure, values/templates, Go templating, hooks, dependencies |
| 11 | [Observability](./11-observability.md) | Logs/Metrics/Traces, Grafana Loki stack, Prometheus/PromQL/Alertmanager, OpenTelemetry, kube-state-metrics |
| 12 | [Troubleshooting](./12-troubleshooting.md) | kubectl debug commands, CrashLoopBackOff, Pending pods, OOMKilled, troubleshooting methodology |
| 13 | [ArgoCD & GitOps](./13-argocd.md) | GitOps, ArgoCD architecture, Applications/AppProjects, sync strategies, hooks/waves, App of Apps, ApplicationSets, RBAC/SSO |
| 14 | [Istio Service Mesh](./14-istio.md) | Service mesh, Istiod, Envoy sidecars, VirtualService, DestinationRule, Gateway, mTLS, PeerAuthentication, AuthorizationPolicy, Kiali/Jaeger |
| 15 | [DevSecOps](./15-devsecops.md) | Shift-left security, SAST/SCA, SLSA/Sigstore/SBOM, image scanning, OPA/Gatekeeper/Kyverno, Falco/Tetragon, NIST/CIS benchmarks |

---

## 🎯 Suggested Pre-Course Learning Path

If you're new to Kubernetes, work through these in order. If you have some experience, jump to the modules that cover your gaps.

**Week 1 — Foundations (Modules 1–4)**
Start here. Understand what Kubernetes is, how it works, and how to talk to it.

**Week 2 — Workloads & Networking (Modules 5–6)**
Learn how to run and expose applications reliably.

**Week 3 — Storage, Security & Advanced Topics (Modules 7–9)**
The production essentials — data persistence, access control, and scaling.

**Week 4 — Ecosystem Tools (Modules 10–15)**
Helm, observability, troubleshooting, GitOps, service mesh, and DevSecOps.

---

## 🔗 Essential Reference Links

- [Kubernetes Official Documentation](https://kubernetes.io/docs/home/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/quick-reference/)
- [CNCF Cloud Native Landscape](https://landscape.cncf.io/)
- [Kubernetes GitHub Repository](https://github.com/kubernetes/kubernetes)
- [Helm Documentation](https://helm.sh/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

*These materials are curated for the January 2026 cohort. Content is continuously updated to reflect the latest Kubernetes releases and ecosystem developments.*
