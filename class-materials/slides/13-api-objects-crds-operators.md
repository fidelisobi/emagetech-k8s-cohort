# Session 13 — Kubernetes API Objects, CRDs & Operators

---

## Kubernetes API Server

- A RESTful web server and critical component of control plane
- Has a list of defined API Resources
- This list can be extended via Custom Resource Definitions (CRDs)

**API Object Maturity:**
- **Alpha** — Disabled by default
- **Beta** — Enabled by default (but in K8s 1.24+, new beta APIs are no longer enabled by default)
- **GA** — Stable and cannot be disabled

**API Groups:**
- Core Group (legacy, e.g., `/api/v1`)
- Named Group (e.g., `/apis/apps/v1`)

---

## API Groups & Functionality

- API Groups — a collection of related functionalities
- Each API Group has one or more versions
- Each API Group-Version contains one or more API types called "Kind"

**API Server Request Pipeline:**

```
kubectl apply -f cert.yaml
        │
        ▼ (1) Decode / deserialize
        ▼ (2) Authenticate (who is this?)
        ▼ (3) Authorize (are they allowed?)
        ▼ (4) Mutating admission webhooks
        ▼ (5) Validating admission webhooks
        ▼ (6) Validate schema
        ▼ (7) Persist to etcd
        ▼ (8) Response to caller
```

---

## Anatomy of a Kubernetes Manifest

- **Type** — specifies object type, group, and API version
  - `apiVersion` and `kind`
- **Object Metadata** — basic object info like name, time of creation, etc.
  - `metadata`
- **Spec** — contains the desired state of the object. Differs for different object types
  - `spec`
- **Status** — shows the current state of the object
  - `status`

> Disclaimer: Not all objects have a spec and status section

---

## API Object - Status

- Usually populated by Controllers, which create an associated "event" object
- Includes a condition field to inform about the state of the Object, e.g.:
  - Node Memory Pressure
  - Node Disk Pressure
  - Node PID Pressure
- Includes other fields:
  - `LastTransitionTime` — when the condition last changed
  - `LastHeartbeatTime` — when the controller last received an update
- As controllers reconcile actual state with desired state in the spec, they generate events (Normal & Warning)

---

## Labels

> **Analogy:** Labels are like luggage tags used by airport staff to route bags — they drive behavior. Annotations are like the baggage claim ticket you keep in your pocket — metadata for reference, not acted on by Kubernetes itself.

- Key-value pairs attached to Kubernetes API objects (e.g., Pods)
- Used to provide identifying attributes to objects
- **Valid Labels:**
  - Must be 63 characters or less
  - Must begin and end with an alphanumeric character `[a-z, 0-9, A-Z]`
  - Can contain dashes (`-`), underscores (`_`), and alphanumerics

**Example — matchLabels and matchExpressions:**

```yaml
selector:
  matchLabels:
    app: web
    tier: frontend
  matchExpressions:
    - key: environment
      operator: In
      values:
        - production
        - staging
    - key: deprecated
      operator: DoesNotExist
```

---

## Labels vs Annotations

| Aspect | Labels | Annotations |
|--------|--------|-------------|
| Purpose | Identifying attributes | Non-identifying metadata |
| Used by Kubernetes | Yes — selectors, scheduling, routing | No — for tooling / humans |
| Can be filtered/selected | Yes (`-l` flag, `matchLabels`) | No |
| Max value length | 63 characters | No practical limit |
| Examples | `app: web`, `env: prod` | build SHA, tool config, last-applied |

---

## Label Selectors

Used to select a set of objects based on their labels.

**Two types:**

**Equality-based (`matchLabels`):**
- Operators: `=`, `==`, `!=`

**Set-based (`matchExpressions`):**
- Operators: `in`, `notin`, `exists`
- Examples:
  - `environment in (production, qa)`
  - `name notin (frontend, backend)`
  - `kubectl get pods -l 'environment in (production,qa)'`
- Supported by ReplicaSets, Deployments, etc.

---

## Annotations

- Key/value pairs used to store non-identifying info
- **Main difference from labels:**
  - Cannot be used to filter, group, or manage a set of API resources
- Use cases: build info, tool configuration, external references

**Example — common annotation added by kubectl:**

```yaml
metadata:
  name: my-deployment
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment",...}
    deployment.kubernetes.io/revision: "3"
    app.example.com/git-sha: "abc1234"
    app.example.com/build-pipeline: "https://ci.example.com/builds/42"
```

---

## Custom Resource Definitions (CRDs)

> **Analogy:** Kubernetes ships with a standard vocabulary (Pod, Deployment, Service). A CRD is like teaching Kubernetes a new word — "Certificate," "ExternalSecret" — so you can describe your intent in your domain's language.

- A Custom Resource is an extension of the Kubernetes API not available in the default installation
- CRDs let you define new resource types
- Once created, new resources are served and handled by the API server
- Managed like any other K8s resource (`kubectl get`, `apply`, `delete`)

**Minimal CRD skeleton:**

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: certificates.cert-manager.io       # must be <plural>.<group>
spec:
  group: cert-manager.io
  names:
    kind: Certificate
    plural: certificates
    singular: certificate
    shortNames: [cert, certs]
  scope: Namespaced                         # or Cluster
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              # ... field definitions
```

---

## Operators Pattern

> **Analogy:** An Operator is a robot SRE. You tell it "I want a 3-replica PostgreSQL cluster with daily backups" (via the CRD), and the Operator does whatever a human DBA would — provisioning storage, running backups, handling failover.

- **Custom Controllers** — manage custom resources
- The **Operator pattern** combines:
  - Custom Resource Definitions (CRDs)
  - Custom Controllers
- Controller watches for changes to the custom resource and reconciles state
- Examples in the wild:
  - cert-manager (Certificate, Issuer CRDs)
  - external-secrets-operator (ExternalSecret, SecretStore CRDs)
  - Prometheus Operator (Prometheus, ServiceMonitor CRDs)
  - ArgoCD (Application, AppProject CRDs)

---

## CRD → Controller Reconciliation Loop

```
┌─────────────────────────────────────────┐
│         Operator / Controller           │
│                                         │
│  Watch ──► Diff ──► Act ──► Update      │
│    ▲                          │         │
│    └──────────────────────────┘         │
└─────────────────────────────────────────┘
        │                   ▲
        ▼                   │
   ┌─────────┐        ┌─────────┐
   │   CRD   │        │  Status │
   │  (spec) │        │ (actual)│
   └─────────┘        └─────────┘
```

- **Watch** — controller subscribes to API server events for the resource
- **Diff** — compares desired state (spec) with actual state (status)
- **Act** — takes whatever action moves actual state toward desired state
- **Update** — writes the new actual state back to status

---

## Aggregation Layer

- Allows extending the Kubernetes API with additional APIs
- The registered extension service runs as a **separate process** (not in-process with the API server)
- Traffic is **proxied through the API server** to the extension service
- Registered via an `APIService` object
- Example: metrics-server exposes `metrics.k8s.io/v1beta1`

---

## Extending Kubernetes - Summary

- **Plugins:** CSI (storage), CNI (networking)
- **Cloud Controller Manager**
- **Webhooks:** Mutating and Validating
- **Controllers & Operators:** CRs/CRDs
- **Scheduling:** Taints & Tolerations, Topology Spread Constraints, Pod Affinity/Anti-Affinity, Node Affinity

---

## Key Takeaways

1. **The API server is the single source of truth** — everything goes through it (auth, admission, validation, etcd persistence).
2. **Beta no longer means "on by default"** — since K8s 1.24, new beta APIs must be explicitly enabled.
3. **CRDs extend the vocabulary** — they let you express domain concepts natively in Kubernetes manifests.
4. **Operators encode operational knowledge** — the reconciliation loop replaces the human operator running repetitive tasks.
5. **Labels drive behavior; annotations store context** — use labels for selection and routing, annotations for tooling metadata and audit trails.
6. **The Aggregation Layer proxies, not embeds** — extension API servers are separate processes; the API server routes traffic to them.
