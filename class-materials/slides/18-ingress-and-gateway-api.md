# Session 18 — Ingress & Gateway API

---

## Ingress

- An API object that exposes HTTP and HTTPS routes from outside the cluster to services within the cluster
- Gives services an externally reachable URL, load balance traffic, SSL/TLS termination, and name-based virtual hosting
- **Ingress Controllers** are required to implement these features — they can be exposed via LoadBalancer Service, NodePort, or HostNetwork

> **Analogy:** An Ingress is like a hotel concierge — guests arrive at one front desk (the load balancer), and the concierge routes them to the right floor and room (service/pod) based on their request.

---

## Ingress Rules

- **Optional Host** — hostname matching
- **List of Paths** — URL path matching
- **Backend** — references a Kubernetes Service

**DefaultBackend:**
- Receives all traffic that does not match any of the rules in the ingress path

---

## Ingress Path Types

| Path Type | Behavior |
|-----------|----------|
| **ImplementationSpecific** | Matches based on IngressClass configuration |
| **Exact** | Matches URL path exactly (case sensitive) |
| **Prefix** | Matches based on URL path prefix split by `/` |

---

## IngressClass

- Contains configuration for a specific Ingress controller
- **Scope:** Cluster-scoped only (not namespace-scoped)
- Multiple IngressClasses can exist in a cluster — one per controller implementation
- Annotate with `ingressclass.kubernetes.io/is-default-class: "true"` to make it the default

---

## Ingress Types & Features

- **Single Service** — route all traffic to one backend
- **Simple Fanout** — route different paths to different services
- **Name-based Virtual Hosting** — route different hostnames to different services
- **TLS** — requires a Secret containing TLS private key and certificate
- **Load Balancing Algorithms** — e.g., weight scheme, etc.

---

## Ingress — Simple Fanout Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fanout-ingress
  namespace: my-app
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
          - path: /web
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

**Real-world scenario:** Requests to `app.example.com/api` go to the API service; `/web` goes to frontend; everything else hits the default backend.

---

## Ingress — TLS Example with cert-manager

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls-secret      # cert-manager creates this Secret
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

cert-manager detects the annotation, provisions a TLS certificate, and stores it in `app-tls-secret`. The Ingress controller then uses it for HTTPS termination.

---

## Gateway API

The evolution of Kubernetes Ingress — a collection of CRDs designed to model service networking.

**Why Gateway API?**
- Ingress limitations: single resource, controller-specific annotations, no TCP/UDP support
- Gateway API graduated to GA (v1.0) — officially recommended by the Kubernetes project

**Key Design Principles:**
- **Role-oriented:** Infrastructure Provider → Cluster Operator → Application Developer
- **Portable:** works across implementations (Istio, Cilium, NGINX, cloud-native)
- **Expressive:** header-based routing, traffic splitting, mirroring built-in
- **Extensible:** custom resources and policy attachment

> **Analogy:** A building's electrical grid — one team wires the building (GatewayClass/infra provider), facilities manages the floor panel (Gateway/cluster operator), and tenants use their office outlets (HTTPRoute/app developer). Each layer configures only what it owns.

---

## Gateway API - Architecture Comparison

```
INGRESS MODEL                    GATEWAY API MODEL
─────────────                    ─────────────────
┌─────────────────┐              ┌─────────────────┐
│  IngressClass   │              │  GatewayClass   │ ◄ infra provider
└────────┬────────┘              └────────┬────────┘
         │                                │
┌────────▼────────┐              ┌────────▼────────┐
│ Ingress resource│              │    Gateway      │ ◄ cluster operator
│ (host+path+svc) │              └────────┬────────┘
└────────┬────────┘                       │
         │                       ┌────────▼────────┐
         │                       │   HTTPRoute     │ ◄ app developer
         │                       └────────┬────────┘
┌────────▼────────┐              ┌────────▼────────┐
│    Service      │              │    Service      │
└─────────────────┘              └─────────────────┘
```

The Ingress model collapses infrastructure, routing, and service concerns into a single resource. Gateway API separates them cleanly across three layers, each owned by a different persona.

---

## Gateway API - Core Resources

**GatewayClass:**
- Defines a class of Gateways (like IngressClass)
- Cluster-scoped, typically one per controller implementation
- Provided by the infrastructure provider

**Gateway:**
- Defines a load balancer / entry point
- Configures listeners on ports and protocols
- Managed by cluster operators
- Can span multiple namespaces via route attachment

**HTTPRoute:**
- Defines HTTP routing rules: path, header, query parameter matching
- Supports traffic splitting (weights), redirects, URL rewrites
- Attaches to a Gateway via `parentRefs`

**Other Route Types:**
- GRPCRoute — gRPC-specific routing
- TCPRoute / UDPRoute / TLSRoute — L4 routing

---

## Gateway API - HTTPRoute Example (Traffic Splitting)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
spec:
  parentRefs:
    - name: my-gateway
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 80
          weight: 90
        - name: api-service-canary
          port: 80
          weight: 10
```

---

## Gateway API - Header-Based Routing Example

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-routing-example
spec:
  parentRefs:
    - name: my-gateway
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: api-service-canary
          port: 80
    - backendRefs:
        - name: api-service
          port: 80
```

Requests with the header `x-version: canary` go to the canary backend. All other requests fall through to the stable backend. Useful for A/B testing and feature flags without changing URLs.

---

## Gateway API - Cross-Namespace Routing & ReferenceGrant

By default, an HTTPRoute in namespace `team-a` cannot reference a Service in namespace `shared-services`. The `ReferenceGrant` resource is the explicit opt-in that allows cross-namespace references.

```yaml
# In the target namespace (shared-services)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-team-a
  namespace: shared-services
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: team-a
  to:
    - group: ""
      kind: Service
```

This lets `team-a`'s HTTPRoutes reference Services in `shared-services`, while the `shared-services` team retains control over who gets access.

---

## Gateway API - Advanced Features

**Traffic Splitting (Canary / Blue-Green):**
- Assign weights to multiple backendRefs
- Native support — no annotations or controller-specific config needed

**Header-Based Routing:**
- Route based on HTTP headers (e.g., `x-version: canary`)
- Useful for A/B testing and feature flags

**Request Mirroring:**
- Mirror traffic to a secondary backend for testing

**URL Rewrites & Redirects:**
- Path prefix replacement, hostname redirect

**TLS Termination:**
- Configured on Gateway listeners, references a Kubernetes Secret
- Works with cert-manager for automatic certificate provisioning (Session 19)

---

## Gateway API vs Ingress

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| Resource model | Single resource | Multi-resource (GatewayClass, Gateway, Routes) |
| Protocol support | HTTP/HTTPS only | HTTP, gRPC, TCP, UDP, TLS |
| Traffic splitting | Annotation-dependent | Native (weights on backendRefs) |
| Header routing | Annotation-dependent | Native (matches) |
| Role separation | No | Yes (infra, cluster ops, app dev) |
| Cross-namespace | No | Yes (route attachment + ReferenceGrant) |

**When to use Ingress:** Simple HTTP routing, existing infrastructure, wide controller support

**When to use Gateway API:** Multi-team environments, advanced traffic management, new greenfield projects

**Both can coexist in the same cluster.** Most Ingress controllers now also support Gateway API.

**Recommendation:** Use Gateway API for new projects.

---

## Key Takeaways

- **Ingress** exposes HTTP/HTTPS routes to Services; it requires an Ingress controller and is built around a single monolithic resource.
- **IngressClass** is cluster-scoped only — there is no namespace-scoped variant.
- **Ingress controllers** can be exposed via LoadBalancer, NodePort, or HostNetwork — not just LoadBalancer.
- **Gateway API** is the Kubernetes-recommended successor to Ingress, now GA. It separates concerns across three roles: infrastructure provider (GatewayClass), cluster operator (Gateway), and app developer (HTTPRoute).
- **ReferenceGrant** is the Gateway API mechanism that explicitly permits cross-namespace references — without it, routes cannot reach Services in other namespaces.
- **Header-based routing, traffic splitting, and URL rewrites** are first-class citizens in Gateway API — no annotations required.
- Both Ingress and Gateway API can coexist; most modern controllers support both.
