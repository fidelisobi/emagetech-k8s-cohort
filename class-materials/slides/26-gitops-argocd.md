# Session 26 — GitOps with ArgoCD

---

## GitOps

A set of procedures that uses the power of Git to provide both revision and change control within the Kubernetes platform.

**GitOps == IT Operations managed from Git**

A DevOps process characterized by:
- Best practices for deployment, management, and monitoring of containerized applications
- A developer-centric experience with fully automated pipelines/workflows
- Use of Git revision control to track and approve changes to infrastructure and runtime environments

**Advantages:**
- Declarative
- Observable
- Auditability and compliance
- Disaster recovery

**Tools:** ArgoCD, Flux

---

## GitOps Analogy

> Git is the architect's blueprint; ArgoCD is the construction foreman who continuously checks that the building matches the blueprint and fixes any unauthorized modifications.

If someone moves a wall without updating the blueprint, the foreman notices and moves it back. No undocumented changes survive. Every change starts in Git — the single source of truth.

---

## ArgoCD Reconciliation Loop

ArgoCD does not deploy once and walk away. It continuously watches both Git and the cluster, closing the gap whenever they diverge.

```
Git commit
     │
     ▼
ArgoCD detects change
     │
     ▼
Diff: desired (Git) vs actual (cluster)
     │
     ▼
Sync: apply changes to cluster
     │
     ▼
Cluster state matches Git ✓
```

This loop runs continuously. If someone runs `kubectl edit` directly on a resource, ArgoCD detects the drift and (when self-heal is enabled) reverts it automatically.

---

## ArgoCD

A declarative, GitOps continuous delivery controller for Kubernetes.

- **Automated Deployment** — controller applies desired state from Git into the cluster
- **Observability** — UI, CLI
- **Multi-Tenancy** — integrates with IdP to provide RBAC for managing multiple clusters

**Features:**
- Automated deployment of apps
- Manage and deploy to multiple clusters
- SSO integration (Okta, SAML, GitHub, etc.)
- Multi-tenancy & RBAC policies for authorization
- Rollback to previous app configuration committed in Git
- Web UI for real-time view of app activity
- Supports multiple config management tools — Helm, Kustomize, or plain YAML

---

## ArgoCD - Components

| Component | Description |
|-----------|-------------|
| **Application Controller** | Manages Application & Project CRDs |
| **ApplicationSet Controller** | Manages ApplicationSet CRD |
| **API Server** | gRPC/REST server for Web UI, CLI, and CI/CD |
| **Repository Server** | Maintains local cache of Git repositories |
| **Dex Server** | User auth with external IdP |
| **Redis Cache** | Stores generated manifests |

**API Server Functions:**
- App management and status reporting
- Invoking app operations (sync, rollback)
- Repository and cluster credential management
- RBAC enforcement

---

## ArgoCD - CRDs

**Application:**
- Represents an instance of a deployable application
- Defines: source (Git repo, path, target revision) + destination (cluster, namespace)

**AppProject (Project):**
- Enables grouping of Applications
- Restricts:
  - What may be deployed (allowed sources)
  - Where apps may be deployed to (allowed destinations)
  - What kinds of objects may or may not be deployed

**ApplicationSet:**
- Manages multiple Applications from a single definition
- Generators: Git, list, cluster, pull request, matrix, merge

---

## ArgoCD - Application CRD Example

A complete Application resource pointing to a Helm chart in Git, targeting a specific namespace on the in-cluster control plane:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/my-org/my-gitops-repo.git
    targetRevision: main          # branch, tag, or commit SHA
    path: apps/my-app/overlays/dev
    helm:
      valueFiles:
        - values-dev.yaml

  destination:
    server: https://kubernetes.default.svc   # in-cluster
    namespace: my-app-dev

  syncPolicy:
    automated:
      prune: true       # delete resources removed from Git
      selfHeal: true    # revert manual changes to the cluster
    syncOptions:
      - CreateNamespace=true
```

Key fields:
- `source.targetRevision` — pin to a branch, tag, or exact SHA
- `destination.server` — use the API server URL or an ArgoCD cluster alias
- `syncPolicy.automated.selfHeal` — enables drift correction

---

## ArgoCD - ApplicationSet with Git Directory Generator

An ApplicationSet generates one Application per directory found in the repository. Useful for managing dozens of microservices from a single resource:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/my-org/my-gitops-repo.git
        revision: main
        directories:
          - path: apps/*           # one Application per folder under apps/
  template:
    metadata:
      name: "{{path.basename}}"   # app name = directory name
    spec:
      project: default
      source:
        repoURL: https://github.com/my-org/my-gitops-repo.git
        targetRevision: main
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Add a new directory to `apps/` and ArgoCD automatically creates and syncs a new Application — no manual step required.

---

## ArgoCD - Credentials

**Repository Credentials:**
- A K8s Secret with a specific label storing credentials to a private repository
- Label: `argocd.argoproj.io/secret-type: repo-cred`

**Cluster Credentials:**
- Stores credentials ArgoCD uses to manage other clusters
- Label: `argocd.argoproj.io/secret-type: cluster`

---

## ArgoCD - Installation

```bash
# Helm (recommended for production)
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace

# Kustomize (see the official docs for the versioned URL)
# Visit https://github.com/argoproj/argo-cd/releases for the latest release,
# then: kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=vX.Y.Z

# Plain YAML (pinned to a specific release tag)
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
```

> Note: Always pin to a specific release tag in production — avoid using `HEAD` or unversioned URLs, which can break unexpectedly.

---

## ArgoCD - Sync Strategies

| Strategy | Behavior |
|----------|----------|
| **Manual** | User triggers sync explicitly |
| **Auto-sync** | ArgoCD automatically syncs when Git changes are detected |
| **Self-heal** | Reverts manual changes made directly to the cluster |
| **Auto-prune** | Deletes resources that are no longer in Git |

**Sync Hooks and Waves:**
- Hooks: PreSync, Sync, PostSync, SyncFail — execute actions at specific phases
- Waves: order resources within a sync phase using `argocd.argoproj.io/sync-wave` annotation
- Lower wave numbers sync first (default is 0)

---

## ArgoCD - Patterns

**App of Apps:**
- A parent Application that manages child Applications
- Single entry point for an entire platform
- Useful for bootstrapping a cluster with all required applications

**ApplicationSets:**
- Template-driven generation of Applications at scale
- Generators produce parameters → template creates Applications
- Use cases:
  - One app per cluster (cluster generator)
  - One app per directory in a Git repo (Git generator)
  - One app per tenant (list generator)
  - Dynamic apps from PRs (pull request generator)

---

## ArgoCD - RBAC & SSO

**RBAC:**
- Policy-based access control using CSV format
- Defines who can do what on which resources
- Built-in roles: `role:readonly`, `role:admin`

**SSO Integration:**
- Dex server handles external IdP authentication
- Supports: OIDC, SAML, LDAP, GitHub, GitLab, Okta
- Maps IdP groups to ArgoCD roles

---

## Key Takeaways

1. **Git is the single source of truth** — every change to the cluster must start as a Git commit; direct `kubectl` edits are treated as drift.
2. **The reconciliation loop never stops** — ArgoCD continuously compares desired state (Git) with actual state (cluster) and corrects differences automatically when self-heal is enabled.
3. **Application CRD = source + destination** — `source` points to a Git path and revision; `destination` points to a cluster and namespace.
4. **ApplicationSets eliminate boilerplate** — a single ApplicationSet with a Git directory generator can manage dozens of applications without repeating Application manifests.
5. **Auto-prune is opt-in** — resources are not deleted automatically unless `prune: true` is explicitly set; this is a safety measure, not a default.
6. **Sync waves control order** — use `argocd.argoproj.io/sync-wave` annotations to ensure CRDs and namespaces are created before the workloads that depend on them.

---

## Review Questions

### Beginner

1. What is GitOps, and how does it differ from a traditional push-based CI/CD pipeline where a pipeline script runs `kubectl apply`?
2. What are the two fields that every ArgoCD `Application` CRD must define, and what does each one describe?
3. What does ArgoCD "drift" mean, and what sync policy setting causes ArgoCD to automatically correct it?
4. What is the difference between `auto-prune: true` and `selfHeal: true` in an ArgoCD sync policy? Why is auto-prune opt-in rather than the default?
5. What problem do sync waves solve, and how does a lower wave number affect when a resource is applied relative to resources with a higher wave number?

### Intermediate

1. Your platform team needs to deploy the same application to 15 different namespaces — one per tenant — each with a slightly different values file. Describe how you would use an ApplicationSet to accomplish this without writing 15 individual Application manifests, and which generator type you would choose.
2. A developer runs `kubectl edit deployment my-app` directly on a production cluster managed by ArgoCD to bump the replica count during an incident. Describe what happens next in terms of ArgoCD's reconciliation loop, how self-heal interacts with the change, and what the correct long-term process should be to avoid this pattern in the future.
