# Day 2 Operations & Capstone

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Why This Matters

Getting a Kubernetes cluster running is Day 1. Keeping it running reliably, cost-efficiently, and securely — for months and years — is Day 2. Day 2 operations is where most of the real complexity lies, and where teams without proper practices accumulate technical debt that eventually causes outages.

Session 30 brings together everything from the course and challenges you to operate Kubernetes as if it were your production cluster. Understanding cluster upgrade strategies, backup and disaster recovery, certificate management, and cost optimization gives you the skills to confidently own a Kubernetes environment — not just deploy to one.

---

## 🎥 YouTube Videos

### Kubernetes Cluster Upgrades - The Right Way
[![Thumbnail](https://img.youtube.com/vi/iXA6lkqbRSk/0.jpg)](https://www.youtube.com/watch?v=iXA6lkqbRSk)
**Channel:** KodeKloud
> Step-by-step guide to upgrading Kubernetes clusters — control plane first, then node pools, with zero-downtime strategies.

### Velero: Kubernetes Backup and Restore
[![Thumbnail](https://img.youtube.com/vi/C9hzrexaIDA/0.jpg)](https://www.youtube.com/watch?v=C9hzrexaIDA)
**Channel:** TechWorld with Nana
> Complete walkthrough of Velero — installing, creating scheduled backups, and restoring from backup after a disaster.

### Kubernetes Cost Optimization Deep Dive
[![Thumbnail](https://img.youtube.com/vi/uITOzpf82RY/0.jpg)](https://www.youtube.com/watch?v=uITOzpf82RY)
**Channel:** Anton Putra
> Practical cost optimization techniques for Kubernetes on AWS — right-sizing, Spot instances, Karpenter, and Cluster Autoscaler.

### Multi-Cluster Kubernetes Strategies
[![Thumbnail](https://img.youtube.com/vi/NOhFPpgNJTY/0.jpg)](https://www.youtube.com/watch?v=NOhFPpgNJTY)
**Channel:** CNCF
> When and why to use multiple Kubernetes clusters — isolation strategies, federation, and cross-cluster service discovery.

---

## 📚 Articles & Documentation

### Cluster Upgrades on GKE
🔗 [GKE Cluster Upgrades](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades)
**Source:** Google Cloud | **Level:** Intermediate
> How GKE handles control plane and node pool upgrades, maintenance windows, and surge upgrades.

### Velero Documentation
🔗 [Velero Docs](https://velero.io/docs/)
**Source:** Velero Project (CNCF) | **Level:** Intermediate
> Complete documentation for Velero — backup/restore, scheduled backups, hooks, and storage providers.

### Kubernetes Certificate Management
🔗 [PKI Certificates and Requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
**Source:** Kubernetes.io | **Level:** Advanced
> Official docs on the certificates used by Kubernetes components and how to rotate them.

### cert-manager Documentation
🔗 [cert-manager](https://cert-manager.io/docs/)
**Source:** cert-manager Project | **Level:** Intermediate
> Automates certificate issuance and renewal using Let's Encrypt, Vault, or self-signed CAs in Kubernetes.

### Kubernetes Cost Optimization Guide
🔗 [GKE Cost Optimization](https://cloud.google.com/kubernetes-engine/docs/best-practices/cost-optimization)
**Source:** Google Cloud | **Level:** Intermediate
> Comprehensive guide to reducing Kubernetes costs on GKE — node sizing, autoscaling, Spot VMs, and resource quotas.

### CNCF Multi-Cluster Whitepaper
🔗 [Multi-Cluster Whitepaper](https://tag-runtime.cncf.io/wgs/multicluster/whitepapers/multicluster-communication/)
**Source:** CNCF | **Level:** Advanced
> CNCF whitepaper on multi-cluster communication patterns, including federation, service mirroring, and Submariner.

---

## Key Concepts

### Cluster Upgrades on Managed Kubernetes

Kubernetes releases a new minor version approximately every 4 months. Running unsupported versions means no security patches. Managed Kubernetes platforms (GKE, EKS, AKS) handle the control plane upgrade for you, but node pool upgrades require careful planning.

**General upgrade strategy**:
1. **Review release notes** for breaking changes, deprecated APIs, and new features
2. **Test in non-production** first — upgrade dev/staging before prod
3. **Upgrade control plane first** — it must always be at the same or higher version than nodes
4. **Upgrade node pools** one pool at a time, using surge upgrades for zero downtime
5. **Monitor workloads** after each step — check for eviction, OOM, or API compatibility issues

**Surge upgrades** (GKE) / **Max Surge** (EKS): Create additional nodes before draining old ones. Workloads are rescheduled to new nodes before old ones are terminated. Zero downtime if your Deployments have enough replicas and PodDisruptionBudgets.

**PodDisruptionBudgets (PDB)**: Guarantee a minimum number of replicas stay running during voluntary disruptions (like node drain):
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2    # or maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

**Deprecated APIs**: Each Kubernetes version removes some deprecated beta APIs. Check with `kubectl-convert` or `pluto` before upgrading:
```bash
# Pluto scans your cluster and Helm releases for deprecated APIs
pluto detect-helm -o wide
```

### Backup and Disaster Recovery

**What needs backing up**:
1. **Cluster state** (etcd): All Kubernetes objects, secrets, configs
2. **Persistent volume data**: Your application data
3. **Configuration outside the cluster**: DNS, load balancer configs, certificates

**Velero**: The standard Kubernetes backup tool. Backs up Kubernetes objects (from the API) and optionally PV data (via snapshots or Restic/Kopia).

```bash
# Install Velero (GCS backend example)
velero install   --provider gcp   --plugins velero/velero-plugin-for-gcp:v1.9.0   --bucket my-velero-backups   --secret-file ./credentials-velero

# Create a scheduled backup
velero schedule create daily-backup   --schedule="0 2 * * *"   --ttl 168h    # keep for 7 days

# Manual backup
velero backup create pre-upgrade-backup --wait

# Restore from backup
velero restore create --from-backup pre-upgrade-backup
```

**etcd snapshots** (self-managed clusters):
```bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt   --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

**RTO and RPO**: Define your Recovery Time Objective (how long can you be down?) and Recovery Point Objective (how much data can you lose?). These drive your backup frequency and DR strategy.

**Disaster recovery testing**: Backups are worthless if you've never tested restoring from them. Schedule quarterly DR drills — actually restore to a test cluster and verify application functionality.

### Certificate Management and Rotation

Kubernetes uses TLS certificates extensively:
- API server certificate
- etcd peer certificates
- kubelet client certificates
- Service account signing keys
- Ingress TLS certificates (exposed to users)

**cert-manager**: The standard Kubernetes-native way to manage TLS certificates. Integrates with Let's Encrypt (ACME), HashiCorp Vault, and self-signed CAs.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
spec:
  secretName: myapp-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - myapp.example.com
```

**Automatic renewal**: cert-manager automatically renews certificates before expiry (default: 30 days before). No manual intervention needed.

**Kubernetes component certificate rotation**:
- Managed clusters (GKE/EKS/AKS): Handled automatically by the platform
- Self-managed: Use `kubeadm certs renew all` annually (certs expire after 1 year by default)

### Cost Optimization

Kubernetes clusters can become expensive if not managed carefully. Key levers:

**Right-sizing**:
- Don't set resource requests too high — over-provisioning wastes money
- Use VPA (Vertical Pod Autoscaler) in "Off" mode to get recommendations:
  ```bash
  kubectl describe vpa myapp  # shows recommended CPU/memory requests
  ```
- Use `kubectl top pods` and `kubectl top nodes` to see actual usage vs. requests

**Spot / Preemptible nodes**: 60-90% cheaper than on-demand, but can be terminated at any time. Best practice:
- Run stateless, fault-tolerant workloads on Spot
- Run stateful or critical workloads on on-demand
- Use node taints and tolerations to control placement:
  ```yaml
  tolerations:
  - key: "cloud.google.com/gke-spot"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  ```

**Karpenter** (AWS) / **GKE Autopilot**: Just-in-time node provisioning. Instead of pre-creating node groups, Karpenter provisions exactly the right node type for each pending pod within seconds.

**Cluster Autoscaler**: Traditional autoscaling — scales node groups up/down based on pending pods and underutilized nodes. Slower than Karpenter but works on all major cloud providers.

**Scheduled scaling**: For predictable traffic patterns (e.g., batch jobs, business hours):
```yaml
# Scale down overnight
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-dev
spec:
  schedule: "0 20 * * 1-5"   # 8pm weekdays
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl
            command: ["kubectl", "scale", "deployment/myapp", "--replicas=0"]
```

**Namespace resource quotas**: Prevent teams from consuming unbounded resources:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    count/pods: "50"
```

**Monitoring costs**: Use tools like Kubecost, OpenCost (CNCF), or cloud-native cost dashboards (GKE Cost Insights, AWS Cost Explorer with EKS tags).

### Multi-Cluster Strategies

**Why multiple clusters**:
- **Environment isolation**: Dev, staging, prod in separate clusters
- **Blast radius reduction**: A cluster-level failure (upgrade gone wrong) only affects one environment
- **Compliance/data residency**: Keep sensitive workloads in dedicated clusters
- **Geographic distribution**: Clusters in multiple regions for latency or availability
- **Team/tenant isolation**: Separate clusters per business unit

**Common patterns**:

| Pattern | Use Case |
|---------|---------|
| Hub-spoke | Central management cluster + many workload clusters |
| Active-active | Multiple production clusters behind a global load balancer |
| Active-passive | Primary + standby cluster for DR |
| Per-environment | dev/staging/prod as separate clusters |

**Fleet management**: ArgoCD ApplicationSets can deploy to multiple clusters from a single repo. Cluster API, GKE Fleet, or Rancher Fleet manage the clusters themselves.

### The Capstone Architecture

The capstone brings together the full Kubernetes stack:

```
┌─────────────────────────────────────────────────────────┐
│                  Production Cluster                      │
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │ Frontend │    │  API     │    │   Database       │  │
│  │ (Nginx)  │───▶│ (Node.js)│───▶│  (PostgreSQL)    │  │
│  └──────────┘    └──────────┘    └──────────────────┘  │
│        │                                                │
│  ┌─────▼──────────────────────────────────────────┐    │
│  │  Ingress / Gateway API                         │    │
│  │  (TLS termination, routing, rate limiting)     │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
│  ┌──────────────────────┐  ┌───────────────────────┐   │
│  │ Prometheus + Grafana │  │  ArgoCD               │   │
│  │ (Metrics, dashboards)│  │  (GitOps deployments) │   │
│  └──────────────────────┘  └───────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         ▲                         ▲
         │                         │
    CI Pipeline               Git Repository
  (GitHub Actions)           (source of truth)
```

**Deployment path**:
1. Docker → local containers working
2. Kubernetes manifests → pods running in cluster
3. Helm chart → parameterized, version-controlled deployment
4. Ingress/Gateway API → external access with TLS
5. Prometheus + Grafana → visibility into health and performance
6. ArgoCD → GitOps-driven deployments, self-healing

---

## Key Concepts to Know Before Class

- What is the recommended order of operations for a Kubernetes cluster upgrade?
- What is a PodDisruptionBudget and why is it essential for zero-downtime upgrades?
- What does Velero back up? What doesn't it back up by default?
- What is an etcd snapshot and when would you need one?
- What is the difference between RTO and RPO?
- How does cert-manager automate TLS certificate management?
- Name three cost optimization strategies for Kubernetes clusters.
- What are Spot/Preemptible nodes and what are the trade-offs?
- How does Karpenter differ from Cluster Autoscaler?
- What is a ResourceQuota and how does it help with multi-team cost management?
- When would you choose multiple clusters over a single cluster with namespaces?
- What tools can you use to monitor Kubernetes costs?
- Describe the components of a production-ready multi-tier application on Kubernetes.

---

## Hands-On Before Class (Optional)

1. **Simulate a cluster upgrade**: Using `kind` or `minikube`, create a cluster at an older K8s version and upgrade it.
2. **Install Velero**: Set up Velero with a local MinIO backend, create a backup, delete a namespace, and restore it.
3. **Install cert-manager**: Deploy cert-manager in a cluster and create a self-signed certificate. Verify the secret is created.
4. **ResourceQuotas**: Create two namespaces with different ResourceQuotas. Try to deploy more pods than the quota allows and observe the error.
5. **Right-sizing exercise**: Deploy a sample workload, run `kubectl top pods`, and compare actual usage to the defined requests/limits.
6. **Cost calculator**: Use the GCP or AWS pricing calculator to estimate the monthly cost of a 3-node cluster. Then estimate the savings from using Spot nodes.
7. **Capstone planning**: Sketch out the architecture for the capstone on paper before class — what components are needed? What order would you deploy them?
