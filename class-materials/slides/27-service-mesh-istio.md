# Session 27 — Service Mesh: Istio

---

## Service Mesh

A service mesh is an architectural pattern for large-scale cloud-native applications composed of many microservices.

**Microservice Challenges:**
- Network unreliability — services are distributed across machines
- Service availability — if one service is down, it could affect dependents
- Traffic flow — difficult to understand how traffic flows through a SOA
- Encryption — services need encrypted communication
- Application health — monitoring can be difficult
- Performance — services must be performant for end users

These could be solved using application-specific libraries, but that has drawbacks:
- Assumptions baked into every application
- Introducing new languages or frameworks becomes harder
- Maintaining libraries across many languages requires significant discipline

---

## Sidecar Analogy

> A bodyguard who travels with every diplomat — handling security, recording interactions, and rerouting when roads are blocked — without changing what the diplomat does.

The diplomat (your app container) never changes its behavior. The bodyguard (Envoy sidecar) handles all the hard parts: encrypting communications, retrying failed routes, collecting a log of every interaction, and redirecting traffic when the usual road is blocked. If you want better security or observability, you upgrade the bodyguard — not every diplomat individually.

---

## Service Mesh - Benefits & Drawbacks

**Benefits:**
- **Resilience** — retries, timeouts, circuit breakers
- **Observability** — metrics and traces to troubleshoot and identify bottlenecks
- **Control** — control over how traffic flows through a network
- **Security** — secures service-to-service communication using mTLS

**Drawbacks:**
- Increased complexity
- Performance overhead
- Vendor lock-in
- Lack of standardization

---

## Service Mesh - Proxy

A proxy is an intermediary component that handles connections and redirects them to appropriate backends.

**Envoy Proxy:**
- Used as a sidecar proxy to every application in the service mesh
- Handles requests from internal and external clients

**Use Cases in a Service Mesh:**
- Establishing, securing, and controlling traffic through the mesh
- Intercepting requests — applying timeouts, retries, circuit breaking
- Collecting metrics and tracing data for observability
- Enforcing policies — access control and rate limiting

---

## Sidecar Injection and Traffic Interception

When a pod is scheduled in a mesh-enabled namespace, Istio's mutating admission webhook automatically injects the Envoy sidecar. iptables rules inside the pod redirect all inbound and outbound traffic through the sidecar — the application container never needs to change.

```
Incoming request
     │
     ▼
┌─────────────────────────────┐
│  Pod                        │
│  ┌──────────┐  ┌─────────┐ │
│  │  Envoy   │─►│  App    │ │
│  │ (sidecar)│◄─│Container│ │
│  └──────────┘  └─────────┘ │
│       ▲                     │
│  iptables redirect          │
└─────────────────────────────┘
```

The app is completely unaware of the mesh. It sends plain HTTP on localhost; Envoy handles mTLS, retries, and telemetry transparently.

Enable sidecar injection per namespace with a label:
```bash
kubectl label namespace my-app istio-injection=enabled
```

---

## Istio

An open source implementation of a service mesh. Originally developed by Google, IBM, and Lyft. A **CNCF graduated project**.

**Istio Architecture:**

**Data Plane:**
- Composed of service proxies (Envoy sidecars) deployed alongside applications
- Configures the proxy to implement policies, manage traffic, generate metrics and traces

**Control Plane:**
- Provides an API for operators to manipulate data plane behavior

---

## Istio - Control Plane (Istiod)

The control plane's main component. Responsible for maintaining the configuration of the data plane.

**Functions:**
- Kubernetes Operator managing CRDs
- **Admission Controller:**
  - Mutating — injects proxy sidecars based on namespace/pod labels
- Certificate issuance and rotation
- Workload identity assignment

---

## Istio - Installation

**istioctl:**
```bash
brew install istioctl
istioctl version
istioctl install --set profile=demo -y
istioctl verify-install
kubectl get pods -n istio-system
```

**Helm (preferred for production):**
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm upgrade istio-base istio/base -n istio-system -i --create-namespace
helm upgrade istiod istio/istiod -n istio-system --wait -i --create-namespace
helm upgrade istio-ingress istio/gateway -n istio-gateways --wait -i --create-namespace
```

---

## Istio Gateways

**Ingress Gateway:**
- Receives incoming traffic from outside the mesh
- Routes to appropriate services within the mesh
- Deployed as a LoadBalancer
- Uses Envoy proxy managed by the Istio control plane

**Egress Gateway:**
- Sends traffic from services within the mesh to external destinations
- Primary use case: **controlling and auditing outbound traffic to external services** (e.g., third-party APIs, databases outside the cluster) — all egress passes through a single choke point for inspection and policy enforcement
- Deployed as a LoadBalancer
- Uses Envoy proxy managed by the Istio control plane

---

## Istio - Network CRDs

| CRD | Purpose |
|-----|---------|
| **Gateway** | Configures Istio Ingress Gateways — controls traffic in/out of mesh. Configures listeners on ports and protocols |
| **VirtualService** | Defines how traffic is routed to a K8s service (like an Ingress resource). Supports A/B testing, canary rollouts, traffic shifting |
| **DestinationRule** | Configures how traffic is treated when it reaches a service. Load balancing, outlier detection, traffic policies. Can target subsets |
| **ServiceEntry** | Defines external services not part of the mesh |
| **Sidecar** | Configures sidecar proxy behavior |
| **ProxyConfig** | Configures Envoy proxy settings |
| **EnvoyFilter** | Customizes Envoy configuration directly |

---

## VirtualService — Canary Traffic Split (80/20)

Route 80% of traffic to the stable version and 20% to the canary, with no application changes required:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
  namespace: my-app
spec:
  hosts:
    - my-app          # matches the Kubernetes Service name
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"   # force canary for specific testers
      route:
        - destination:
            host: my-app
            subset: canary
    - route:           # default route: weighted split
        - destination:
            host: my-app
            subset: stable
          weight: 80
        - destination:
            host: my-app
            subset: canary
          weight: 20
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app
  namespace: my-app
spec:
  host: my-app
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

Adjust `weight` values over time to progressively shift traffic to the canary before full promotion.

---

## Istio - Security CRDs

**Authentication:**

| CRD | Purpose |
|-----|---------|
| **PeerAuthentication** | Configures mTLS between services. Modes: STRICT (require mTLS), PERMISSIVE (accept both), DISABLE |
| **RequestAuthentication** | Configures auth requirements for incoming requests (JWT, mTLS). Defines identity providers for valid tokens |

**Authorization:**

| CRD | Purpose |
|-----|---------|
| **AuthorizationPolicy** | Defines access control rules for services/workloads. Evaluates conditions based on service name, namespace, labels, source IP |

---

## PeerAuthentication — STRICT mTLS for a Namespace

Enforce mutual TLS for all services in the `payments` namespace. Any pod without a valid Istio identity certificate will be rejected:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: payments       # applies to all workloads in this namespace
spec:
  mtls:
    mode: STRICT            # only accept mTLS connections; reject plain text
```

Common modes:
- `STRICT` — require mTLS; use for production namespaces handling sensitive data
- `PERMISSIVE` — accept both mTLS and plain text; use during migration to give services time to get sidecars
- `DISABLE` — turn off mTLS entirely (rarely needed)

Apply a mesh-wide default by placing a `PeerAuthentication` with `STRICT` in the `istio-system` namespace:
```yaml
metadata:
  name: default
  namespace: istio-system
```

---

## Istio - Observability

Built-in observability through Envoy sidecars:
- **Kiali** — service mesh visualization and management
- **Jaeger** — distributed tracing
- **Built-in metrics** — request rate, error rate, latency (RED metrics automatically)

---

## When to Use (and When Not to Use) a Service Mesh

**Use when:**
- Many microservices communicating over the network
- Need for mTLS without application changes
- Complex traffic routing (canary, A/B, fault injection)
- Regulatory requirement for encryption in transit

**Don't use when:**
- Small number of services
- Monolithic application
- Team lacks operational capacity for the added complexity
- Latency requirements are extremely tight

---

## Key Takeaways

1. **The mesh lives in the sidecar, not the app** — Envoy is injected automatically; your application code requires zero changes to gain mTLS, retries, and telemetry.
2. **iptables is the secret** — all traffic in and out of a pod is transparently redirected through the Envoy sidecar via iptables rules injected at pod startup.
3. **VirtualService controls routing; DestinationRule controls behavior** — use VirtualService for traffic splitting and header matching; use DestinationRule to define subsets and load-balancing policies.
4. **Start with PERMISSIVE mTLS, graduate to STRICT** — PERMISSIVE allows unmeshed services to still communicate during rollout; flip to STRICT once all workloads have sidecars.
5. **Egress Gateway = outbound choke point** — route all external traffic through the Egress Gateway to enforce policies and audit what leaves the cluster.
6. **Operational cost is real** — a service mesh adds ~10 ms of latency per hop and increases resource usage; validate that the benefits outweigh the overhead before adopting in latency-sensitive systems.

---

## Review Questions

### Beginner

1. What is a service mesh, and what four categories of problems does it solve that application code alone would otherwise need to handle?
2. How does Istio inject the Envoy sidecar into a pod, and what does the application container need to change to make this work?
3. What is the difference between `VirtualService` and `DestinationRule` in Istio? Give a one-sentence description of what each CRD controls.
4. What are the three `PeerAuthentication` mTLS modes (`STRICT`, `PERMISSIVE`, `DISABLE`), and in which scenario would you use `PERMISSIVE` rather than `STRICT`?
5. What is the primary purpose of an Istio Egress Gateway, and why is routing outbound traffic through it valuable from a security perspective?

### Intermediate

1. Your team wants to roll out a new version of a payment service with minimal risk. Describe how you would use Istio `VirtualService` and `DestinationRule` together to implement a canary deployment that starts at 10% traffic and allows specific testers to always hit the new version via a request header.
2. A monolithic application is being broken into 12 microservices. A teammate argues that you should adopt Istio immediately for the security and observability benefits. Another teammate argues the operational overhead outweighs the gains at this stage. What factors would you evaluate to make this decision, and under what conditions would you recommend deferring the service mesh adoption?
