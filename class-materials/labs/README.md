# Hands-On Lab Exercises — Kubernetes January 2026 Cohort

This directory contains all hands-on lab exercises for the GKE training course. Each lab is self-contained with YAML manifests, supporting scripts, and step-by-step instructions.

---

## Lab Index

| Lab | Session | Topic | Key Resources |
|-----|---------|-------|---------------|
| [11 — Architecture](./11-architecture/) | 11 | Explore your cluster | Nodes, namespaces, API health |
| [12 — kubectl](./12-kubectl/) | 12 | kubectl essentials | Pods, output formatting, dry-run |
| [13 — API Objects](./13-api-objects/) | 13 | Labels, selectors, and CRDs | Labels, selectors, CRD, custom resources |
| [14 — Pod Lifecycle](./14-pod-lifecycle/) | 14 | Probes, QoS, and debugging | Probes, init containers, QoS classes |
| [15 — ConfigMaps & Secrets](./15-configmaps-secrets/) | 15 | Configuration injection | ConfigMap, Secret, Downward API, volumes |
| [16 — Pod Controllers](./16-pod-controllers/) | 16 | Deployments, StatefulSets, Jobs | Deployment, StatefulSet, Job, CronJob |
| [17 — Network Policies](./17-network-policies/) | 17 | Zero-trust pod networking | NetworkPolicy |
| [18 — Gateway API](./18-gateway-api/) | 18 | Next-gen Kubernetes ingress | GatewayClass, Gateway, HTTPRoute |
| [19 — Platform Add-ons](./19-platform-addons/) | 19 | TLS automation with cert-manager | ClusterIssuer, Certificate, Ingress |
| [20 — Storage](./20-storage/) | 20 | Persistent volumes | PVC, PV, StorageClass, volumeClaimTemplates |
| [21 — RBAC](./21-rbac/) | 21 | Access control and quotas | Role, RoleBinding, ServiceAccount, ResourceQuota |
| [22 — Troubleshooting](./22-troubleshooting/) | 22 | Debugging broken resources | CrashLoopBackOff, ImagePullBackOff, Pending, kubectl debug |
| [23 — Scaling](./23-scaling/) | 23 | HPA and topology-aware scheduling | HPA, TopologySpreadConstraints |
| [24 — Helm](./24-helm/) | 24 | Kubernetes package manager | Helm CLI (no YAML — CLI-driven lab) |
| [25 — Observability](./25-observability/) | 25 | Metrics, alerts, and logs | ServiceMonitor, PrometheusRule, PromQL, LogQL |
| [26 — ArgoCD](./26-argocd/) | 26 | GitOps continuous delivery | ArgoCD Application, selfHeal, Helm sources |
| [27 — Istio Traffic](./27-istio-traffic/) | 27 | Service mesh traffic management | VirtualService, DestinationRule, PeerAuthentication |
| [28 — Policy](./28-policy/) | 28 | Admission control with Kyverno | ClusterPolicy |
| [29 — CI/CD](./29-cicd/) | 29 | Build and deploy pipelines | Cloud Build, Trivy, GitOps flow |
| [30 — Day 2 Operations](./30-day2-ops/) | 30 | Backup, PDB, and upgrades | Velero, PodDisruptionBudget, kubent |

---

## Prerequisites Summary

| Lab | Required Cluster Components |
|-----|----------------------------|
| 11–16 | GKE cluster (any) |
| 17 | GKE Dataplane V2 or Calico (default on GKE) |
| 18 | Istio, Gateway API CRDs (v1.0+) |
| 19 | cert-manager, Cloud DNS API, GCP SA |
| 20 | StorageClass `standard` (default on GKE) |
| 21 | GKE cluster (any) |
| 22 | GKE cluster (any) |
| 23 | Metrics Server (default on GKE) |
| 24 | Helm CLI installed locally |
| 25 | kube-prometheus-stack, Loki |
| 26 | ArgoCD |
| 27 | Istio, Bookinfo app in `bookinfo` namespace |
| 28 | Kyverno |
| 29 | Cloud Build, Artifact Registry |
| 30 | Velero |

---

## General Lab Workflow

```bash
# 1. Read the lab README for context and prerequisites
cat labs/NN-topic/README.md

# 2. Apply setup/infrastructure files first
kubectl apply -f labs/NN-topic/00-setup.yaml   # if it exists

# 3. Apply each numbered file in sequence
kubectl apply -f labs/NN-topic/01-*.yaml
kubectl apply -f labs/NN-topic/02-*.yaml

# 4. Run the verification commands from the README

# 5. Discuss and answer the discussion questions

# 6. Clean up at the end
kubectl delete namespace <lab-namespace>
```

---

## Tips for Students

- Read the comments in each YAML file — they explain every field
- Use `kubectl describe` to inspect the status of any resource
- Use `kubectl get events -n <namespace>` to debug scheduling or admission issues
- Use `kubectl explain <resource>.<field>` to look up any field in the API
- When stuck, follow the troubleshooting flowchart in Session 22
