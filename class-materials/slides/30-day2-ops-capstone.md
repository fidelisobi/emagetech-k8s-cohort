# Session 30 — Day 2 Operations & Capstone

---

## Cluster Upgrades

Managed Kubernetes simplifies upgrades but doesn't eliminate planning.

**Cluster Upgrade Analogy**

> Like upgrading a plane's engine while it's in flight — you do it one engine at a time, never all at once.

You cannot land the plane (take the cluster offline), so each node is drained, upgraded, and returned to service before the next one begins. PodDisruptionBudgets are the mechanism that ensures a minimum number of replicas stay airborne throughout.

**Control Plane Upgrade:**
- GKE: automatic or manual — select target version
- EKS/AKS: initiate upgrade via CLI/console/Terraform
- **Always upgrade one minor version at a time** (1.29 → 1.30, not 1.29 → 1.31)

**Node Pool Upgrade Strategies:**

| Strategy | How It Works | Trade-off |
|----------|-------------|-----------|
| **Surge** | Add new nodes → drain old → remove old | Fast, needs extra capacity |
| **Blue/Green** | New node pool → migrate workloads → delete old pool | Safest, most resources |
| **In-place** | Upgrade nodes one at a time | Slowest, fewest resources |

**Pre-Upgrade Checklist:**
- Check API deprecations: `kubent` (kube-no-trouble)
- Review release notes for breaking changes
- Test upgrade in non-production environment first
- Ensure PodDisruptionBudgets are configured
- Verify all third-party controllers/operators support the target version

---

## Backup & Disaster Recovery

### Velero (CNCF incubating project)
Backup and restore Kubernetes resources and persistent volumes.

**What Velero backs up:**
- All Kubernetes API objects (Deployments, Services, ConfigMaps, etc.)
- Persistent Volume snapshots (via CSI or cloud provider)
- Can filter by namespace, label, or resource type

**Key Commands:**
```bash
velero backup create my-backup                           # full backup
velero backup create my-backup --include-namespaces prod  # namespace backup
velero schedule create daily --schedule="0 2 * * *"       # scheduled backup
velero restore create --from-backup my-backup             # restore
```

**Disaster Recovery Scenarios:**
- Cluster migration — backup from old, restore to new cluster
- Namespace recovery — restore specific namespace from backup
- Accidental deletion — restore individual resources

### etcd Snapshots (for self-managed clusters)
- Managed K8s handles etcd backups automatically
- For self-managed: `etcdctl snapshot save` / `etcdctl snapshot restore`
- Understanding this matters for CKA exam

---

## Velero Schedule CRD Example

Use the `Schedule` CRD to define recurring automated backups declaratively, so they survive cluster restores and can be managed via GitOps:

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: nightly-full-backup
  namespace: velero
spec:
  # Cron expression: every day at 02:00 UTC
  schedule: "0 2 * * *"

  template:
    # Keep backups for 7 days before automatic deletion
    ttl: 168h0m0s

    # What to back up
    includedNamespaces:
      - production
      - staging
    excludedResources:
      - events           # high-churn, low-value objects
      - events.events.k8s.io

    # Include PV snapshots (requires CSI snapshot support or cloud provider plugin)
    snapshotVolumes: true
    volumeSnapshotLocations:
      - gcp-default      # defined in a BackupStorageLocation CRD

    storageLocation: default   # defined in a BackupStorageLocation CRD

    # Labels to apply to the backup objects for filtering
    labelSelector:
      matchLabels:
        backup-tier: critical
```

Verify schedules and last backup status:
```bash
velero schedule get
velero backup get
velero backup describe nightly-full-backup-<timestamp> --details
```

---

## Cost Optimization

Kubernetes cost drivers: **compute (nodes), storage (PVs), networking (LBs)**

### Right-Sizing Workloads
- Use VPA recommendations to set accurate requests/limits
- Over-requesting wastes resources; under-requesting causes OOMKills
- Tools: kubecost, kubectl-cost, GKE cost attribution

### Spot / Preemptible Nodes
- 60-90% cheaper than on-demand
- Best for: stateless, fault-tolerant workloads
- Use taints + tolerations to schedule appropriate workloads
- **Not suitable for:** databases, stateful workloads, long-running batch jobs

### Scheduled Scaling
- Scale down non-production clusters outside business hours
- CronJobs to scale node pools or use cluster pause/resume
- Example: destroy dev cluster at 2 AM, recreate at 10 AM

### Other Savings
- Namespace Resource Quotas — prevent runaway consumption
- Unused resource cleanup: orphaned PVCs, idle LoadBalancers, old images in registries
- Committed use discounts (GCP CUDs, AWS Savings Plans, Azure Reservations)

---

## Certificate Management

Kubernetes uses TLS certificates extensively.

**Managed K8s (GKE/EKS/AKS):**
- Control plane certificates — managed and auto-rotated by cloud provider
- Node certificates — kubelet certificates auto-rotated

**Application Certificates:**
- cert-manager handles issuance and renewal (covered in Session 19)
- Monitor certificate expiry with Prometheus alerts:
  - `certmanager_certificate_expiration_timestamp_seconds`

**Service Mesh Certificates (Istio):**
- Istiod acts as a CA — issues mTLS certs to sidecars
- Automatic rotation — configurable via MeshConfig

**Best Practice:** Never manually manage certificates in production.

---

## Multi-Cluster Strategies (Overview)

| Pattern | Use Case |
|---------|----------|
| **Active-Active** | High availability across regions, traffic split |
| **Active-Passive** | DR cluster on standby, failover on primary failure |
| **Hub-and-Spoke** | Central management cluster, workload clusters |
| **Federation** | Shared API across clusters (still evolving) |

**Tools:** ArgoCD (multi-cluster), Cilium Cluster Mesh, Submariner, Istio multi-cluster

---

## Multi-Cluster Architecture Diagrams

Choose the topology that matches your availability and operational requirements:

```
Active-Active              Active-Passive           Hub-and-Spoke
┌────────┐ ┌────────┐     ┌────────┐ ┌────────┐   ┌────────┐
│Cluster │ │Cluster │     │Primary │ │Standby │   │  Hub   │
│   A    │ │   B    │     │        │ │(idle)  │   │(mgmt)  │
│ (live) │ │ (live) │     │ (live) │ │        │   └───┬────┘
└────┬───┘ └────┬───┘     └────────┘ └────────┘   ┌───┼────┐
     └────┬─────┘              failover ──►        ▼   ▼    ▼
     Traffic split                              Spoke Spoke Spoke
```

**Active-Active:** Both clusters serve live traffic simultaneously. A global load balancer (e.g., Cloud DNS, Cloudflare) splits requests. Best for maximum availability and geographic distribution. Requires data replication and conflict resolution.

**Active-Passive:** One cluster handles all traffic; the standby cluster is idle until the primary fails. Simpler to operate but wastes standby capacity. Velero backups + restore is a common failover mechanism.

**Hub-and-Spoke:** A central "hub" cluster runs management tooling (ArgoCD, monitoring, policy engines). Spoke clusters run workloads and are managed from the hub. Common pattern for platform teams managing many tenant clusters.

---

## Capstone Project

Deploy a multi-tier application end-to-end on managed Kubernetes.

**Architecture:** Frontend + API + Database (PostgreSQL)

### Tasks

| # | Task | Session Reference |
|---|------|-------------------|
| 1 | **Containerize:** Build Docker images for frontend and API | Sessions 1–5 |
| 2 | **Registry:** Push images to Artifact Registry / ECR / ACR | Session 4 |
| 3 | **Helm:** Create a Helm chart with values per environment | Session 24 |
| 4 | **Secrets:** Use external-secrets-operator for DB credentials | Session 19 |
| 5 | **Deploy:** PostgreSQL StatefulSet + API Deployment + Frontend Deployment | Sessions 14, 16 |
| 6 | **Networking:** Services, Ingress/Gateway API with TLS (cert-manager) | Sessions 17–19 |
| 7 | **DNS:** external-dns for automatic DNS record creation | Session 19 |
| 8 | **Observe:** Prometheus + Grafana dashboards, Loki for logs | Session 25 |
| 9 | **GitOps:** Manage deployment via ArgoCD Application | Session 26 |
| 10 | **Scale:** Configure HPA for API, test under load | Session 23 |

**Bonus:** CI pipeline (GitHub Actions / Cloud Build) with image scanning (Session 29)

---

## Capstone Starter — Helm Chart Scaffold

Use this as your starting point for Task 3. Fill in the values and add templates incrementally.

```yaml
# charts/my-app/Chart.yaml
apiVersion: v2
name: my-app
description: Multi-tier capstone application (frontend + API + PostgreSQL)
type: application
version: 0.1.0          # chart version — bump this on every chart change
appVersion: "latest"    # override with the actual image tag at deploy time
keywords:
  - capstone
  - kubernetes
maintainers:
  - name: your-name
    email: your-email@example.com
dependencies:
  # Pull in the Bitnami PostgreSQL chart as a sub-chart
  - name: postgresql
    version: "15.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled   # allows disabling in envs that use an external DB
```

```yaml
# charts/my-app/values.yaml

# --- Frontend ---
frontend:
  image:
    repository: us-docker.pkg.dev/my-project/my-repo/frontend
    tag: ""              # set at deploy time: helm upgrade --set frontend.image.tag=$SHA
    pullPolicy: IfNotPresent
  replicaCount: 2
  service:
    type: ClusterIP
    port: 80
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

# --- API ---
api:
  image:
    repository: us-docker.pkg.dev/my-project/my-repo/api
    tag: ""
    pullPolicy: IfNotPresent
  replicaCount: 2
  service:
    type: ClusterIP
    port: 8080
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 512Mi
  env:
    DATABASE_HOST: ""    # populated from ExternalSecret or Helm value
    DATABASE_NAME: myapp

# --- PostgreSQL (Bitnami sub-chart) ---
postgresql:
  enabled: true          # set to false if using a managed DB (Cloud SQL, RDS, etc.)
  auth:
    database: myapp
    existingSecret: db-credentials   # Secret created by external-secrets-operator
    secretKeys:
      adminPasswordKey: password
      userPasswordKey: password
  primary:
    persistence:
      enabled: true
      size: 10Gi

# --- Ingress ---
ingress:
  enabled: true
  className: nginx
  host: myapp.example.com
  tls:
    enabled: true
    secretName: myapp-tls   # managed by cert-manager

# --- Autoscaling ---
autoscaling:
  enabled: false           # enable for the Scale task (Task 10)
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

Deploy with:
```bash
# Install chart dependencies first
helm dependency update charts/my-app

# Deploy to dev
helm upgrade --install my-app charts/my-app \
  --namespace my-app-dev \
  --create-namespace \
  -f charts/my-app/values-dev.yaml \
  --set frontend.image.tag=$SHA \
  --set api.image.tag=$SHA
```

---

## Key Takeaways

1. **Upgrade one minor version at a time** — skipping versions is unsupported and risks subtle data plane failures; always test upgrades in a non-production cluster first.
2. **Velero is CNCF incubating** — it is production-ready and widely adopted for backup/restore; use the Schedule CRD to manage recurring backups declaratively via GitOps.
3. **Multi-cluster topology is a business decision** — Active-Active maximises availability but requires data replication; Active-Passive is simpler; Hub-and-Spoke suits platform teams managing many clusters.
4. **Right-size before you scale** — over-provisioned requests waste money silently; run VPA in recommendation mode for a week before setting production resource requests.
5. **PodDisruptionBudgets are upgrade safety nets** — configure them for all stateful and business-critical workloads so node drains during upgrades never take a service below its minimum replicas.
6. **The capstone integrates every session** — containerization, Helm, secrets, networking, observability, GitOps, and autoscaling are not independent topics; in production they all interlock exactly as the capstone tasks demonstrate.
