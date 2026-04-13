# Istio Service Mesh

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Istio is the most widely adopted service mesh for Kubernetes — it transparently handles traffic management, security (mTLS), and observability for microservices without requiring application code changes. This section covers Istio's architecture (Istiod control plane, Envoy sidecar data plane), key traffic management CRDs (VirtualService, DestinationRule, Gateway), security primitives (PeerAuthentication, AuthorizationPolicy), and observability tools (Kiali, Jaeger).

---

## 🎥 YouTube Videos

### Istio & Service Mesh — Simply Explained in 15 Mins
[![Thumbnail](https://img.youtube.com/vi/16fgzklcF7Y/0.jpg)](https://www.youtube.com/watch?v=16fgzklcF7Y)
**Channel:** TechWorld with Nana
> The most accessible introduction to Istio and the service mesh concept — explains the problems Istio solves, the sidecar pattern, and the control/data plane split in 15 minutes.

### Istio Service Mesh Tutorial For Beginners | Learn Istio in 30 Minutes
[![Thumbnail](https://img.youtube.com/vi/oJnLRSj8UkY/0.jpg)](https://www.youtube.com/watch?v=oJnLRSj8UkY)
**Channel:** KodeKloud
> 30-minute tutorial covering Istio fundamentals — monolith vs. microservices challenges, service mesh concepts, and how Istio addresses them.

### Istio Tutorial (Service Mesh — Ingress Gateway, Virtual Service, Gateway, mTLS)
[![Thumbnail](https://img.youtube.com/vi/H4YIKwAQMKk/0.jpg)](https://www.youtube.com/watch?v=H4YIKwAQMKk)
**Channel:** Anton Putra
> Hands-on Istio tutorial covering real cluster setup — Ingress Gateway, VirtualService, traffic routing, and mTLS configuration with working YAML examples.

### Service Mesh Explained in 60 Minutes | Istio mTLS and Observability
[![Thumbnail](https://img.youtube.com/vi/eSNetKBe7Z8/0.jpg)](https://www.youtube.com/watch?v=eSNetKBe7Z8)
**Channel:** CNCF
> Deep-dive from a CNCF talk covering the full Istio feature set including mTLS, circuit breaking, observability with Kiali and Jaeger, and AuthorizationPolicy.

### What is Istio? Service Mesh for Kubernetes
[![Thumbnail](https://img.youtube.com/vi/B1QfWlrtfSE/0.jpg)](https://www.youtube.com/watch?v=B1QfWlrtfSE)
**Channel:** DevOps Journey
> Short, concise explainer on Istio as a Kubernetes service mesh — great first watch to understand the concept before diving into configuration.

---

## 📚 Articles & Documentation

### Istio Getting Started
🔗 [Istio Getting Started](https://istio.io/latest/docs/setup/getting-started/)
**Source:** istio.io | **Level:** Beginner
> Official Istio quickstart — installs Istio on a Kubernetes cluster, deploys the Bookinfo sample app, and demonstrates traffic management, telemetry, and security features.

### Istio Security Concepts
🔗 [Istio Security](https://istio.io/latest/docs/concepts/security/)
**Source:** istio.io | **Level:** Intermediate
> Comprehensive overview of Istio's security model — covers identity (SPIFFE/X.509), mTLS, PeerAuthentication for configuring mTLS per workload/namespace, and AuthorizationPolicy for access control.

### PeerAuthentication Reference
🔗 [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)
**Source:** istio.io | **Level:** Intermediate
> API reference for `PeerAuthentication` — the CRD that configures mTLS requirements for workloads. Covers modes: PERMISSIVE (accepts both plaintext and mTLS), STRICT (mTLS only), DISABLE.

### Traffic Management
🔗 [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
**Source:** istio.io | **Level:** Intermediate
> Explains VirtualService (routing rules), DestinationRule (load balancing, circuit breaking, connection pooling), Gateway (external traffic), and ServiceEntry (external services).

### Beginner's Guide: What is Istio Service Mesh?
🔗 [What is Istio Service Mesh?](https://konghq.com/blog/learning-center/what-is-istio-service-mesh)
**Source:** konghq.com | **Level:** Beginner
> Accessible explanation of Istio's architecture — covers the sidecar injection mechanism, Istiod control plane, and how Envoy proxies enable transparent traffic management.

### Service Mesh Architecture with Istio
🔗 [Service Mesh Architecture with Istio](https://www.baeldung.com/ops/istio-service-mesh)
**Source:** baeldung.com | **Level:** Intermediate
> Practical 2025 tutorial showing how to install Istio, configure traffic routing, enable mTLS, and view telemetry — with working code examples throughout.

---

## 🗝️ Key Concepts to Know Before Class
- **Service mesh** adds a transparent proxy layer (Envoy sidecar) to every pod, enabling traffic management, mTLS, and observability without code changes.
- **Istiod** is the unified control plane: it manages certificates (Citadel), pushes Envoy configs (Pilot), and validates resources (Galley). One component since Istio 1.5.
- **VirtualService** defines routing rules — route 90% of traffic to v1 and 10% to v2, or route based on headers/URI. **DestinationRule** defines *how* to reach a destination — load balancing algorithm, circuit breaker settings, mTLS mode.
- **Gateway** exposes services outside the mesh — similar to Ingress but with more control over L7 routing. Pair with a VirtualService to route external traffic.
- **mTLS** (mutual TLS) means both parties in a connection authenticate each other. Istio can enforce strict mTLS cluster-wide using `PeerAuthentication` with `mode: STRICT`.
- **AuthorizationPolicy** is Istio's L7 firewall — allows/denies traffic based on source workload identity (SPIFFE), JWT claims, HTTP methods/paths.
- **Kiali** provides a service mesh topology graph; **Jaeger/Zipkin** provides distributed traces; **Prometheus** collects Envoy telemetry.
