# Session 21 — Namespaces, RBAC & Multi-Tenancy

---

## Namespaces

- Provides a mechanism for isolating groups of resources within a single cluster
- Names of API resources **must** be unique within a namespace
- Names can be reused in other namespaces
- Used to implement multi-tenancy for multiple teams/departments
- Namespaces cannot be nested
- Provides a way to divide cluster resources between multiple users/teams

**Initial Namespaces at cluster creation:**
- `default`
- `kube-node-lease`
- `kube-public`
- `kube-system`

---

## Security - Containers & Pods

**Blast radius of a vulnerable pod:**
- Access another pod?
- Create another pod?
- Control a node?
- Move from one node to another?
- Connect to external services (e.g., database)?
- Access secrets or source control?

**Vulnerability** — a security-based weakness in our app
**Intrusion** — a break-in by a bad actor based on this weakness

---

## Security - Containers/Pods

**Container Security:**
- Update containers and binaries regularly
- Apply best practices when building container images
- Regularly scan containers/images to identify vulnerabilities

**Pod Security:**
- **SecurityContext:**
  - `runAsUser` — user ID to start process
  - `runAsGroup` — group ID for the process user
  - `fsGroup` — second group ID for mounted volumes/files
  - `allowPrivilegeEscalation` — prevent child process from gaining more privileges
- Prevent processes from running as root (UserID = 0)
- Always use a non-root user and add capabilities as needed
- Do not automount the service account token unless needed
- Linux Kernel Security: AppArmor, SELinux, or seccomp

---

## Pod Security Standards (PSS)

Replaced PodSecurityPolicies (removed in K8s v1.25). Applied per namespace via labels.

| Level | Description | Use For |
|-------|-------------|---------|
| **Privileged** | No restrictions — full access | System-level workloads (CNI, CSI, monitoring) |
| **Baseline** | Prevents known privilege escalations. Blocks: hostPID, hostIPC, hostNetwork, privileged containers, and dangerous capabilities | Standard workloads |
| **Restricted** | Hardened best practices. Requires: non-root, drop ALL capabilities, read-only root FS | Security-sensitive workloads |

> **Note on Baseline and hostPath:** Baseline does not unconditionally block hostPath volumes. It restricts specific high-risk fields (hostPID, hostIPC, hostNetwork, privileged). HostPath volume restrictions are part of the Restricted profile. Always verify the exact controls in the [official PSS documentation](https://kubernetes.io/docs/concepts/security/pod-security-standards/).

**Enforcement Modes:** `enforce`, `audit`, `warn`

**Apply to namespace:**
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## Security - Nodes

- Immutable node OS or patch nodes regularly
- Resource attacks — set requests/limits to mitigate DoS impact
- Protect network:
  - Limit access to node's network — Network Policies
  - Prevent external access to Pods (firewall rules)

---

## Security - API Server (RBAC)

RBAC — Role-Based Access Control. Used to restrict access to the API Server.

**Analogy:** Think of a hospital access card system. A Role is the set of permissions encoded on a badge type (nurse, surgeon). A RoleBinding is the act of issuing that badge to a specific person. A ClusterRole is a master-key badge that is valid in all wings of the hospital, not just one department.

**RBAC API Objects:**

| Object | Scope | Purpose |
|--------|-------|---------|
| **Role** | Namespace | Set of permissions limited to a namespace |
| **ClusterRole** | Cluster | Set of permissions cluster-wide |
| **RoleBinding** | Namespace | Grants a Role or ClusterRole to subjects within a namespace |
| **ClusterRoleBinding** | Cluster | Grants a ClusterRole to subjects cluster-wide |

**Subjects:** Users, ServiceAccounts, Groups

**Verbs for API Resources:**
`get`, `list`, `create`, `update`, `patch`, `watch`, `delete`, `deletecollection`

---

## RBAC Request Flow

```
Pod (ServiceAccount: ci-runner)
     │
     ▼ API request
┌────────────────────┐
│    API Server      │
│                    │
│ 1. Authn: Who?     │──► ServiceAccount: ci-runner in ns: dev
│ 2. Authz: Allowed? │──► Check RoleBindings → Role → Verbs
│ 3. Result          │──► Allow or Deny
└────────────────────┘
```

Every request to the API server goes through Authentication (who are you?) and then Authorization (are you allowed to do this?). RBAC is the most common authorization mechanism.

---

## Role + RoleBinding YAML Example

Give the `ci-runner` ServiceAccount read access to Pods in namespace `dev`:

```yaml
# 1. The Role — defines what is allowed
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
  - apiGroups: [""]        # "" = core API group
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

---
# 2. The RoleBinding — grants the Role to a subject
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-runner-pod-reader
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: ci-runner
    namespace: dev
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## Resource Quotas

Limits the aggregate resource consumption per namespace. Enforced by the ResourceQuota admission controller.

**Compute Resource Quotas:**
- `requests.cpu`, `requests.memory` — total requests across all Pods
- `limits.cpu`, `limits.memory` — total limits across all Pods

**Object Count Quotas:**
- `count/pods`, `count/services`, `count/configmaps`, `count/secrets`
- `count/deployments.apps`, `count/statefulsets.apps`

**Storage Quotas:**
- `requests.storage` — total PVC storage
- `persistentvolumeclaims` — number of PVCs
- Can be scoped per StorageClass

**Important:** When a ResourceQuota exists in a namespace, all Pods **must** specify requests/limits.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    count/pods: "20"
    count/services: "10"
    requests.storage: 50Gi
```

---

## LimitRanges

Sets default and min/max resource constraints for individual containers. Unlike ResourceQuota (namespace aggregate), LimitRange is per-Pod/container.

**Key Fields:**
- `default` — default limits if container doesn't specify
- `defaultRequest` — default requests if not specified
- `min` — minimum resource requirement
- `max` — maximum resource allowed
- `maxLimitRequestRatio` — max ratio of limit/request

**Types:**
- `Container` — individual containers (most common)
- `Pod` — sum of all containers in a Pod
- `PersistentVolumeClaim` — min/max storage size

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: dev
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: "2"
        memory: 2Gi
      min:
        cpu: 50m
        memory: 64Mi
```

**Best Practice:** Always set LimitRanges as a safety net.

---

## Workload Identity — Cloud IAM to K8s RBAC

**Problem:** Pods need to access cloud APIs (GCS, S3, Key Vault). Old approach: store cloud credentials as K8s Secrets — insecure, hard to rotate.

**Solution:** Bind K8s ServiceAccounts to cloud IAM — no keys needed.

**GKE Workload Identity:**
- K8s ServiceAccount → annotated → maps to GCP IAM ServiceAccount
- Annotation: `iam.gke.io/gcp-service-account: SA@PROJECT.iam.gserviceaccount.com`

**AWS IRSA (IAM Roles for Service Accounts):**
- K8s ServiceAccount → annotated → assumes AWS IAM Role via OIDC
- Annotation: `eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/ROLE`

**Azure Workload Identity:**
- K8s ServiceAccount → Federated Identity Credential → Azure Managed Identity

**Best Practice:** Always use Workload Identity over static credentials.

---

## Security - Network & Multi-Tenancy

**Network Security:**
- Network Policies
- Service Mesh — Istio, Linkerd (mTLS)
- Policy engines — OPA/Gatekeeper, Kyverno

**Multi-Tenancy Best Practices:**
- Have a private API server endpoint
- Use RBAC rules with ServiceAccounts
- Use Network Policies
- Cluster tenants should be in namespaces
- Utilize Resource Quotas
- Limit Pods that have access to hostNetwork
- Use policy governance tools (OPA/Gatekeeper, Kyverno)

---

## Key Takeaways

- Namespaces provide soft isolation — they are not a security boundary by themselves; combine them with RBAC, NetworkPolicies, and ResourceQuotas
- Follow the principle of least privilege: grant only the verbs and resources a workload actually needs
- Prefer Role + RoleBinding over ClusterRole + ClusterRoleBinding unless cluster-wide access is genuinely required
- ResourceQuotas enforce namespace-level aggregate limits; LimitRanges enforce per-container defaults and caps — use both together
- PSS Baseline blocks the most dangerous escalation vectors (hostPID, hostIPC, hostNetwork, privileged containers); use Restricted for workloads that can tolerate stricter constraints
- Use Workload Identity (GKE/IRSA/Azure WI) instead of storing cloud credentials as Kubernetes Secrets
- Audit RBAC regularly: `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>`

---

## Review Questions

### Beginner

1. What are the four initial namespaces created in a Kubernetes cluster, and what is each used for?
2. What is the difference between a `Role` and a `ClusterRole`? When would you use a `ClusterRoleBinding` instead of a `RoleBinding`?
3. What is the difference between a `ResourceQuota` and a `LimitRange`? What does each one enforce?
4. What are the three Pod Security Standards levels, and which is appropriate for a standard application workload that doesn't need privileged access?
5. What does the principle of least privilege mean in the context of Kubernetes RBAC?

### Intermediate

1. A namespace has a `ResourceQuota` applied, but Pods in that namespace are failing to schedule with an error about missing resource requests. Why is this happening, and what must developers do to resolve it?
2. Your security team has flagged that a CI pipeline's ServiceAccount has `ClusterRoleBinding` to `cluster-admin`. Describe the risks this introduces and the steps you would take to replace it with a least-privilege RBAC configuration scoped only to what the pipeline actually needs.
3. A pod labeled `app: scraper` needs to call the Kubernetes API to list pods and read ConfigMaps in its own namespace. Write out the Role and RoleBinding YAML required to grant exactly this access and nothing more.
