# Hands-On Lab Exercises — Kubernetes January 2026 Cohort

This directory contains all hands-on lab exercises for the GKE training course. Each lab is self-contained with YAML manifests, supporting scripts, and step-by-step instructions.

---

## Lab Index

| Lab | Topic | Estimated Time | Key Resources |
|---|---|---|---|
| [17 — Network Policies](./17-network-policies/) | Zero-trust pod networking | 30–40 min | NetworkPolicy |
| [18 — Gateway API](./18-gateway-api/) | Next-gen Kubernetes ingress | 35–45 min | GatewayClass, Gateway, HTTPRoute |
| [19 — Platform Addons](./19-platform-addons/) | TLS automation with cert-manager | 40–50 min | ClusterIssuer, Certificate, Ingress |
| [23 — Scaling](./23-scaling/) | HPA and topology-aware pod placement | 45–60 min | HorizontalPodAutoscaler, TopologySpreadConstraints |
| [27 — Istio Traffic](./27-istio-traffic/) | Service mesh traffic management | 45–60 min | DestinationRule, VirtualService, PeerAuthentication |
| [28 — Policy](./28-policy/) | Admission control with Kyverno | 40–50 min | ClusterPolicy |

---

## Lab 17 — Network Policies

**Directory:** `17-network-policies/`

Deploy a multi-tier app and apply network policies to implement zero-trust pod networking.

| File | Description |
|---|---|
| `00-setup.yaml` | Namespace, frontend/backend/attacker deployments and services |
| `01-default-deny-all.yaml` | Default deny all ingress and egress |
| `02-allow-frontend-to-backend.yaml` | Selective allow: frontend pods → backend on port 8080 |
| `03-allow-egress-dns.yaml` | Allow DNS egress (port 53) to restore name resolution |

**Concepts covered:** podSelector, policyTypes, ingress/egress rules, port-level filtering

---

## Lab 18 — Gateway API

**Directory:** `18-gateway-api/`

Explore the next-generation Kubernetes ingress standard, including path-based routing and traffic splitting.

| File | Description |
|---|---|
| `01-gateway.yaml` | GatewayClass (Istio controller) + Gateway with HTTP/HTTPS listeners |
| `02-httproute-basic.yaml` | HTTPRoute: `/api` → api-service, `/web` → frontend with URL rewrite |
| `03-httproute-traffic-split.yaml` | HTTPRoute with 90/10 weighted canary split |

**Concepts covered:** GatewayClass, Gateway, HTTPRoute, parentRefs, path matching, weight-based routing

---

## Lab 19 — Platform Addons: cert-manager

**Directory:** `19-platform-addons/`

Automate TLS certificate issuance and renewal using cert-manager and Let's Encrypt.

| File | Description |
|---|---|
| `01-clusterissuer.yaml` | ClusterIssuer with Let's Encrypt staging + Cloud DNS DNS01 solver |
| `02-certificate.yaml` | Certificate resource with SANs, duration, and auto-renewal config |
| `03-ingress-with-tls.yaml` | Ingress using cert-manager annotation for automatic cert management |

**Concepts covered:** ClusterIssuer, Certificate, ACME DNS01 challenge, Ingress TLS, auto-renewal

---

## Lab 23 — Scaling

**Directory:** `23-scaling/`

Scale workloads automatically based on CPU metrics and distribute pods across failure zones.

| File | Description |
|---|---|
| `01-hpa.yaml` | HPA targeting 70% CPU utilization, min=2, max=10 with scale behavior |
| `02-load-test.sh` | Bash script that launches a busybox pod generating HTTP load |
| `03-topology-spread.yaml` | Deployment with zone and node spread constraints (maxSkew=1) |

**Concepts covered:** HPA control loop, resource requests vs limits, stabilizationWindowSeconds, topologyKey, maxSkew, DoNotSchedule vs ScheduleAnyway

---

## Lab 27 — Istio Traffic Management

**Directory:** `27-istio-traffic/`

Control traffic flow between microservices using the Istio service mesh. All exercises target the Bookinfo app in the `bookinfo` namespace.

| File | Description |
|---|---|
| `01-destination-rule.yaml` | DestinationRule for reviews with v1/v2/v3 subsets + circuit breaker |
| `02-virtualservice-v1-only.yaml` | Route 100% of traffic to reviews v1 (baseline) |
| `03-virtualservice-canary.yaml` | 80/20 split with header-based override for QA testing |
| `04-peer-authentication.yaml` | STRICT mTLS for the entire bookinfo namespace |
| `05-fault-injection.yaml` | 5-second delay on 50% of requests to ratings service |

**Concepts covered:** DestinationRule subsets, VirtualService weights, header matching, PeerAuthentication, fault injection, circuit breaker

---

## Lab 28 — Policy Enforcement with Kyverno

**Directory:** `28-policy/`

Enforce governance rules at admission time using Kyverno ClusterPolicies.

| File | Description |
|---|---|
| `01-kyverno-require-labels.yaml` | Block pods missing `app` or `team` labels |
| `02-kyverno-require-limits.yaml` | Block pods with containers that have no CPU/memory limits |
| `03-kyverno-disallow-latest.yaml` | Block pods using `:latest` or untagged container images |

**Concepts covered:** ClusterPolicy, validationFailureAction (Enforce/Audit), pattern matching, foreach, exclude namespaces, PolicyReport

---

## Prerequisites Summary

| Lab | Required Cluster Components |
|---|---|
| 17 — Network Policies | GKE Dataplane V2 or Calico (enabled by default on GKE) |
| 18 — Gateway API | Istio, Gateway API CRDs (v1.0+) |
| 19 — Platform Addons | cert-manager, Cloud DNS API enabled, GCP service account |
| 23 — Scaling | Metrics Server (enabled by default on GKE) |
| 27 — Istio Traffic | Istio, Bookinfo app deployed in `bookinfo` namespace |
| 28 — Policy | Kyverno (install via Helm) |

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
# ...

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
