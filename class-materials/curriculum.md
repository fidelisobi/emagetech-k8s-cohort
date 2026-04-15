# Docker & Kubernetes Curriculum

> Professional training program — from container fundamentals to production Kubernetes on managed cloud platforms (GKE/EKS/AKS).

---

## Part 1: Docker & Containers

### Session 1 — Why Docker + Containers vs VMs

- The problem Docker solves: dependency hell, environment drift, "works on my machine"
- Virtual Machines vs Containers — architecture comparison, resource overhead, startup time
- Container use cases: microservices, CI/CD, dev/prod parity
- The OCI standard — images, runtimes, registries
- Docker Desktop vs Docker Engine — when to use which

### Session 2 — Docker Architecture

- Docker Engine: daemon, CLI, REST API
- Client-server model
- containerd and runc under the hood
- Image layers and the union filesystem (OverlayFS)
- Copy-on-write and how containers share base layers

### Session 3 — Running Containers

- `docker run` — flags, detached mode, interactive mode
- Port mapping, environment variables, restart policies
- Container lifecycle: create, start, stop, pause, kill, rm
- Inspecting containers: `logs`, `exec`, `inspect`, `stats`
- Resource constraints: `--memory`, `--cpus`

### Session 4 — Images Deep Dive

- Image anatomy: manifests, layers, digests, tags
- Building images: `docker build`, build context, `.dockerignore`
- Multi-stage builds — minimizing image size
- Container registries: Docker Hub, GCR/Artifact Registry, ECR, ACR
- Pushing, pulling, tagging strategies (semver, SHA, `latest` pitfalls)
- Image pull policies and authentication (ties into Kubernetes `imagePullSecrets`)

### Session 5 — Dockerfile Best Practices & Advanced Builds

- Instruction order and layer caching
- Reducing image size: minimal base images (distroless, Alpine, scratch)
- `ARG` vs `ENV`, `COPY` vs `ADD`, `ENTRYPOINT` vs `CMD`
- Multi-stage builds for compiled languages
- BuildKit features: cache mounts, secrets, SSH forwarding
- Linting with hadolint

### Session 6 — Docker Networking

- Default networks: bridge, host, none
- User-defined bridge networks
- Container DNS and service discovery
- Port publishing and network isolation
- Network drivers overview (bridge, overlay, macvlan)

### Session 7 — Docker Volumes

- The ephemeral filesystem problem
- Volume types: named volumes, bind mounts, tmpfs
- Volume lifecycle and data persistence
- Volume drivers and remote storage
- Backup and migration patterns

### Session 8 — Docker Compose & Multi-Container Apps

- Why Compose: defining multi-service applications
- `docker-compose.yml` anatomy: services, networks, volumes
- Service dependencies and health checks
- Environment files and variable substitution
- Compose for local development workflows
- Bridge to Kubernetes: how Compose concepts map to K8s objects

### Session 9 — Container Internals

- Linux namespaces: PID, NET, MNT, UTS, IPC, USER
- cgroups v1 vs v2 — resource limits and accounting
- Capabilities and privilege model
- seccomp profiles and AppArmor/SELinux
- How a container is really just a process

### Session 10 — Container Security

- Attack surface of containers
- Image scanning: Trivy, Grype, Snyk
- Supply chain security: image signing (cosign/Sigstore), SBOMs
- Running as non-root, read-only filesystems
- Secrets management in containers (don't bake them into images)
- CIS Docker Benchmark overview

---

## Part 2: Kubernetes

### Session 11 — Kubernetes Architecture

- Control plane components: API server, etcd, scheduler, controller manager
- Worker node components: kubelet, kube-proxy, container runtime (CRI)
- CoreDNS and cluster DNS
- The declarative model: desired state vs current state
- Control loops and reconciliation
- Managed Kubernetes differences: what GKE/EKS/AKS abstract away (control plane, etcd, upgrades)

### Session 12 — Connecting to a Cluster & kubectl Essentials

- kubeconfig: contexts, clusters, users
- Connecting to managed clusters (`gcloud container clusters get-credentials`, `aws eks update-kubeconfig`, `az aks get-credentials`)
- kubectl fundamentals: `get`, `describe`, `apply`, `delete`, `logs`, `exec`
- Imperative vs declarative usage
- Output formatting: `-o yaml`, `-o json`, `-o jsonpath`, `--dry-run=client`
- API discovery: `api-resources`, `api-versions`, `explain`

### Session 13 — Kubernetes API Objects, CRDs & Operators

- Everything is an API object: Group, Version, Resource (GVR)
- Core objects overview: Pod, Service, Deployment, ConfigMap, Secret
- Manifest anatomy: `apiVersion`, `kind`, `metadata`, `spec`, `status`
- Labels, selectors, and annotations
- Custom Resource Definitions (CRDs) — extending the API
- Operators pattern: CRD + custom controller
- API versioning: alpha, beta, GA — stability guarantees

### Session 14 — Pod Lifecycle

- What is a Pod — the smallest deployable unit
- Pod phases: Pending, Running, Succeeded, Failed, Unknown
- Container states: Waiting, Running, Terminated
- Init containers and sidecar containers
- Probes: liveness, readiness, startup — configuration and failure behavior
- Resource requests and limits — how the scheduler uses them
- Quality of Service classes: Guaranteed, Burstable, BestEffort
- Pod disruption budgets

### Session 15 — ConfigMaps, Secrets & Environment Configuration

- ConfigMaps: creation, mounting as volumes, injecting as env vars
- Secrets: types (Opaque, TLS, docker-registry), encoding vs encryption
- Secrets management in production: external-secrets-operator, Vault integration (deep dive in Session 19)
- The Downward API — exposing Pod metadata
- Projected volumes — combining multiple sources
- Immutable ConfigMaps and Secrets

### Session 16 — Managed Pods (Pod Controllers)

- Why you never run naked Pods in production
- Deployments and ReplicaSets — rolling updates, rollbacks
- StatefulSets — stable identity, ordered deployment, persistent storage
- DaemonSets — one Pod per node
- Jobs and CronJobs — batch and scheduled workloads
- Deployment strategies: rolling update, recreate
- Advanced rollout strategies: canary, blue-green, A/B (Argo Rollouts overview)

### Session 17 — Networking

- Kubernetes networking model: every Pod gets an IP, no NAT
- CNI plugins: what they do, popular options (Cilium, Calico, VPC-native)
- Services: ClusterIP, NodePort, LoadBalancer, ExternalName
- Service discovery: DNS-based (`<svc>.<ns>.svc.cluster.local`)
- EndpointSlices and how Services route traffic
- kube-proxy modes: iptables vs IPVS vs eBPF (Cilium)
- Network Policies: ingress/egress rules, default deny patterns

### Session 18 — Ingress & Gateway API

- Why Services alone aren't enough for HTTP traffic
- Ingress resources and Ingress controllers (NGINX, cloud-native)
- Host-based and path-based routing
- TLS termination and cert-manager integration (deep dive in Session 19)
- Gateway API: the next generation — Gateway, HTTPRoute, GRPCRoute
- Gateway API vs Ingress — when to use which
- Cloud provider load balancer integration

### Session 19 — Platform Add-ons & Cluster Tooling

- The common pattern: CRD + controller reconciling external state — why these tools all work the same way
- **cert-manager**: automated TLS certificate lifecycle
  - ClusterIssuer vs Issuer — cluster-wide vs namespace-scoped
  - ACME / Let's Encrypt integration
  - Certificate resources and automatic renewal
  - Integration with Ingress annotations and Gateway API
  - DNS-01 vs HTTP-01 challenge solvers
- **external-dns**: automatic DNS record management
  - Syncing DNS from Ingress, Service, and Gateway resources
  - Provider configuration: Cloud DNS, Route53, Azure DNS
  - Ownership and TXT registry — preventing record conflicts
  - Filtering by annotation, namespace, or source type
- **external-secrets-operator**: syncing secrets from external stores
  - SecretStore vs ClusterSecretStore
  - ExternalSecret resource — mapping external keys to K8s Secret keys
  - Supported backends: GCP Secret Manager, AWS Secrets Manager, Azure Key Vault, HashiCorp Vault
  - Refresh intervals and secret rotation
  - Comparison with Sealed Secrets and SOPS
- **Reloader**: automatic rollout restarts on ConfigMap/Secret changes
  - Annotation-based opt-in
  - Why Kubernetes doesn't do this natively
- **Putting it together**: a full workflow — cert-manager provisions TLS, external-dns creates the DNS record, external-secrets injects credentials, Reloader restarts Pods when secrets rotate

### Session 20 — Storage

- The ephemeral container filesystem (recap from Docker)
- Persistent Volumes (PV) and Persistent Volume Claims (PVC)
- StorageClasses and dynamic provisioning
- Access modes: ReadWriteOnce, ReadOnlyMany, ReadWriteMany
- Cloud provider storage: GCE PD, EBS, Azure Disk, Filestore/EFS
- Volume expansion, snapshots, and cloning
- StatefulSet + PVC patterns

### Session 21 — Namespaces, RBAC & Multi-Tenancy

- Namespaces: logical isolation, when to use them
- Resource Quotas and LimitRanges — guardrails per namespace
- RBAC components: Roles, ClusterRoles, RoleBindings, ClusterRoleBindings
- Service accounts and their tokens
- RBAC patterns: least-privilege, namespace-scoped admin
- Cloud IAM to Kubernetes RBAC mapping (Workload Identity, IRSA, Azure AD)
- Pod Security Standards: Privileged, Baseline, Restricted
- Multi-tenancy strategies overview

### Session 22 — Troubleshooting

- Troubleshooting methodology: a systematic approach
- Pod issues: Pending, CrashLoopBackOff, ImagePullBackOff, OOMKilled, CreateContainerConfigError
- Service/networking issues: DNS resolution, endpoint debugging
- Node issues: NotReady, resource pressure, taints
- Key commands: `kubectl describe`, `kubectl logs`, `kubectl events`, `kubectl debug`
- Ephemeral debug containers
- Common gotchas and how to avoid them

### Session 23 — Scaling: Pods & Nodes

- Horizontal Pod Autoscaler (HPA) — CPU, memory, custom metrics
- Vertical Pod Autoscaler (VPA) — right-sizing recommendations
- Cluster Autoscaler — node pool scaling
- Karpenter — just-in-time node provisioning (EKS/AKS)
- GKE Autopilot vs Standard — scaling models
- Node affinity, taints/tolerations, topology spread constraints
- Pod priority and preemption

### Session 24 — Helm

- Why Helm: templating, packaging, versioning
- Helm concepts: charts, releases, repositories
- Chart anatomy: `Chart.yaml`, `values.yaml`, templates
- Go template syntax: `{{ .Values }}`, `{{ include }}`, `{{ range }}`
- Installing, upgrading, rolling back releases
- Creating your own chart
- Helm hooks and chart dependencies
- Helmfile and declarative Helm management

### Session 25 — Observability

- The three pillars: logs, metrics, traces
- **Metrics**: Prometheus architecture, scraping, PromQL basics
- **Alerting**: Alertmanager — routing, grouping, silencing
- **Dashboards**: Grafana — data sources, dashboards, panels
- **Logging**: Grafana Loki — log aggregation, LogQL basics
- kube-state-metrics and node-exporter
- OpenTelemetry overview — vendor-neutral instrumentation
- What to monitor: the USE and RED methods

### Session 26 — GitOps with ArgoCD

- GitOps principles: Git as single source of truth
- ArgoCD architecture: Application Controller, Repo Server, API Server
- Installing and accessing ArgoCD
- Applications and AppProjects
- Sync strategies: manual, auto-sync, self-heal, auto-prune
- Sync hooks and waves — ordering deployments
- App of Apps pattern
- ApplicationSets — managing many apps at scale
- ArgoCD RBAC and SSO integration

### Session 27 — Service Mesh: Istio

- What problems does a service mesh solve
- Istio architecture: Istiod (Pilot, Citadel, Galley), Envoy sidecars
- Traffic management: VirtualService, DestinationRule
- Gateway resources and ingress
- mTLS: PeerAuthentication — STRICT, PERMISSIVE
- Authorization policies — workload-to-workload access control
- Observability: Kiali, Jaeger, built-in metrics
- When to use (and when not to use) a service mesh

### Session 28 — DevSecOps & Policy Enforcement

- Shift-left security: scanning in CI/CD pipelines
- Image scanning in CI: Trivy, Grype
- Infrastructure-as-Code scanning: Checkov, tfsec
- Admission controllers: what they are, how they work
- Policy engines: OPA/Gatekeeper, Kyverno — writing and enforcing policies
- Runtime security: Falco, Tetragon — detecting anomalous behavior
- CIS Kubernetes Benchmark overview
- SLSA framework and supply chain levels

### Session 29 — CI/CD Pipelines for Kubernetes

- Building container images in CI (GitHub Actions, Cloud Build, Azure Pipelines)
- Image tagging, promotion, and registry workflows
- GitOps-driven deployment: CI builds, CD (ArgoCD) deploys
- Pipeline patterns: build > scan > push > update manifest > sync
- Environment promotion strategies: dev > staging > production
- Secrets in pipelines: Workload Identity Federation, OIDC

### Session 30 — Day 2 Operations & Capstone

- Cluster upgrades on managed K8s: control plane and node pool strategies
- Backup and disaster recovery: Velero, etcd snapshots
- Certificate management and rotation
- Cost optimization: right-sizing, spot/preemptible nodes, scheduled scaling
- Multi-cluster strategies overview
- Capstone project: deploy a multi-tier application end-to-end
  - Containerize with Docker
  - Deploy to managed K8s with Helm
  - Expose via Ingress/Gateway API
  - Observe with Prometheus + Grafana
  - Manage with ArgoCD

---

## Additional / Recommended Self-Study

These topics are valuable but outside the core curriculum. Students are encouraged to explore them independently.

### Cluster Bootstrapping & Installation

> Since this course uses managed Kubernetes (GKE/EKS/AKS), cluster installation is handled by the cloud provider. Understanding bootstrap tooling is useful for on-prem scenarios and deepening your architectural knowledge.

- kubeadm: initializing and joining nodes
- k3s / k3d: lightweight Kubernetes for edge and local dev
- kind (Kubernetes in Docker): local clusters for testing
- Cluster API (CAPI): declarative cluster lifecycle management
- kubespray: Ansible-based cluster provisioning
- The hard way: [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

### Cloud-Specific Deep Dives

- GKE: Autopilot, Config Connector, Workload Identity, Binary Authorization
- EKS: Karpenter, IRSA, EKS Blueprints, Pod Identity
- AKS: Azure AD integration, NAP (Node Autoprovision), AKS Automatic

### Advanced Networking

- eBPF and Cilium deep dive
- Multi-cluster networking (Submariner, Cilium Cluster Mesh)
- IPv4/IPv6 dual-stack

### Platform Engineering

- Internal Developer Platforms (IDPs)
- Crossplane — infrastructure as Kubernetes resources
- Backstage — developer portals

---

## Suggested Study Timeline

| Week | Docker Sessions | Kubernetes Sessions |
|------|----------------|---------------------|
| 1 | Sessions 1–3 (Why Docker, Architecture, Running Containers) | — |
| 2 | Sessions 4–5 (Images, Dockerfiles) | — |
| 3 | Sessions 6–8 (Networking, Volumes, Compose) | — |
| 4 | Sessions 9–10 (Internals, Security) | — |
| 5 | — | Sessions 11–13 (K8s Architecture, kubectl, API Objects) |
| 6 | — | Sessions 14–16 (Pod Lifecycle, ConfigMaps, Controllers) |
| 7 | — | Sessions 17–19 (Networking, Ingress/Gateway, Platform Add-ons) |
| 8 | — | Sessions 20–21 (Storage, RBAC/Namespaces) |
| 9 | — | Sessions 22–23 (Troubleshooting, Scaling) |
| 10 | — | Sessions 24–25 (Helm, Observability) |
| 11 | — | Sessions 26–27 (ArgoCD, Istio) |
| 12 | — | Sessions 28–30 (DevSecOps, CI/CD, Day 2 Ops/Capstone) |

---

*Kubernetes January 2026 Cohort — Emagetech*
