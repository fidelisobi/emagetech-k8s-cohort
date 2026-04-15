# Session 19 — Platform Add-ons & Cluster Tooling

---

## Overview

Production clusters need more than just Kubernetes primitives. These tools follow a common pattern: **CRD + Controller reconciling external state** — the Operator pattern in action.

**Key Platform Add-ons:**
- **cert-manager** — automated TLS certificate lifecycle
- **external-dns** — automatic DNS record management
- **external-secrets-operator** — sync secrets from external stores
- **Reloader** — restart workloads when ConfigMaps/Secrets change

They're installed on almost every production cluster and they work together for end-to-end workflows.

---

## cert-manager - Overview

Automates the management and issuance of TLS certificates. A **CNCF graduated project**.

> **Analogy:** Like setting up automatic car insurance renewal — configure once, it handles renewals before expiry without you having to remember.

**Key CRDs:**
| CRD | Description |
|-----|-------------|
| `Issuer` | Namespace-scoped certificate authority |
| `ClusterIssuer` | Cluster-wide certificate authority |
| `Certificate` | Represents a desired TLS certificate |
| `CertificateRequest` | A single request to an Issuer |

**Supported Certificate Authorities:**
- Let's Encrypt (ACME) — free, automated, most common
- HashiCorp Vault — enterprise PKI
- Venafi, AWS PCA, Google CAS, self-signed

**Installation:**
```bash
helm install cert-manager jetstack/cert-manager --set crds.enabled=true
```

---

## cert-manager - ACME & Challenge Solvers

ACME (Automated Certificate Management Environment) — used by Let's Encrypt to verify domain ownership.

> **Analogy:** HTTP-01 is like verifying you own a house by placing a specific object in the front window — anyone can see it's there. DNS-01 is like verifying via county records — only the owner can change them, so it's a stronger proof.

**HTTP-01 Challenge:**
- cert-manager creates a temporary Pod/Ingress to serve a token
- Works with any Ingress controller or Gateway API
- Requires port 80 to be reachable from the internet
- Best for: single-domain certificates

**DNS-01 Challenge:**
- cert-manager creates a TXT record in your DNS provider
- Supports Cloud DNS, Route53, Azure DNS, Cloudflare, etc.
- Best for: **wildcard certificates** (`*.example.com`)
- Does not require port 80 — works for internal services

---

## cert-manager - Certificate Flow

```
Ingress (annotation)
     │
     ▼
Certificate ──► CertificateRequest
                      │
                      ▼
              [ACME Solver]  ──►  Let's Encrypt
                      │
                      ▼
              TLS cert + key stored in K8s Secret
                      │
                      ▼
              Ingress/Gateway uses Secret for TLS
```

cert-manager monitors the Certificate resource and automatically repeats this flow before expiry (default: 30 days before expiration).

---

## cert-manager - ClusterIssuer Example

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          cloudDNS:
            project: my-gcp-project
```

> **Warning:** Let's Encrypt has strict rate limits (5 duplicate certificate failures per hour, 50 certificates per domain per week). Always use the **staging server** (`https://acme-staging-v02.api.letsencrypt.org/directory`) first when testing. Staging certs are not trusted by browsers but let you verify your workflow without burning production quota.

**Integration with Ingress:** annotation `cert-manager.io/cluster-issuer: letsencrypt-prod`

**Integration with Gateway API:** via Certificate resource referencing a Gateway

---

## cert-manager - Certificate Resource Example

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls
  namespace: my-app
spec:
  secretName: app-tls-secret          # K8s Secret that will hold the cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: app.example.com
  dnsNames:
    - app.example.com
    - www.app.example.com
  duration: 2160h                     # 90 days
  renewBefore: 720h                   # renew 30 days before expiry
```

Use a `Certificate` resource when you need fine-grained control over duration, renewal window, or multiple SANs — rather than relying solely on Ingress annotations.

---

## cert-manager - Certificate Lifecycle

**Automatic Certificate Workflow:**
1. Create a Certificate resource (or annotate Ingress/Gateway)
2. cert-manager creates a CertificateRequest
3. Challenge solver proves domain ownership
4. CA issues the certificate
5. cert-manager stores cert + key in a Kubernetes Secret
6. Ingress/Gateway/application uses the Secret for TLS

**Automatic Renewal:**
- Certificates renewed before expiry (default: 30 days before)
- No manual intervention required

**Monitoring:**
- cert-manager exposes Prometheus metrics
- Alert on: certificates near expiry, failed issuance

---

## external-dns - Overview

Automatically manages DNS records based on Kubernetes resources. A **CNCF incubating project**.

> **Analogy:** Without external-dns: you open a new store but forget to update the address in Google Maps — customers can't find you. With external-dns: the Maps entry updates automatically when the store opens.

**Problem it solves:**
- Without it: deploy app → manually create DNS record → configure Ingress
- With it: deploy Ingress/Service/Gateway → DNS record created automatically

**Supported Sources (Kubernetes resources):**
- Ingress, Service (LoadBalancer), Gateway API HTTPRoute, Istio VirtualService

**Supported DNS Providers:**
- GCP Cloud DNS, AWS Route53, Azure DNS, Cloudflare, and 30+ more

**Installation:**
```bash
helm install external-dns kubernetes-sigs/external-dns
```

---

## external-dns - How It Works

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│ K8s Resources│────►│ external-dns  │────►│ DNS Provider │
│ (Ingress,    │     │ controller    │     │ (Cloud DNS,  │
│  Service,    │     │               │     │  Route53)    │
│  Gateway)    │     │ compare +     │     │              │
│              │     │ reconcile     │     │ A/CNAME/TXT  │
└──────────────┘     └───────────────┘     └──────────────┘
```

**Reconciliation Loop:**
1. Watches Kubernetes resources (Ingress, Service, Gateway)
2. Extracts hostnames from resource specs/annotations
3. Compares desired DNS records with actual records in the DNS provider
4. Creates, updates, or deletes DNS records to match desired state

**Ownership Model:**
- Uses TXT records to track which DNS records it manages
- Prevents conflicts with manually created records

**Filtering:**
- By annotation: `external-dns.alpha.kubernetes.io/hostname`
- By namespace, source type, or domain filter

**Policy:**
- `sync` — create + delete (full reconciliation)
- `upsert-only` — create only, never delete

---

## external-dns - Configuration Example

```yaml
# Helm values (GCP Cloud DNS)
provider: google
google:
  project: my-gcp-project
domainFilters:
  - example.com
policy: sync
sources:
  - ingress
  - service
  - gateway-httproute
```

**Ingress Annotation:**
```yaml
external-dns.alpha.kubernetes.io/hostname: app.example.com
```

> **Warning:** `policy: sync` will **delete** DNS records that external-dns previously created if the corresponding Kubernetes resource is removed. If `domainFilters` is too broad (e.g., `example.com` instead of `apps.example.com`), it can delete manually-managed records in that zone. Use `upsert-only` during initial rollout, and narrow your `domainFilters` before switching to `sync`.

**Authentication:** Workload Identity (GKE), IRSA (EKS), Azure AD (AKS)

---

## external-secrets-operator - Overview

Syncs secrets from external secret management systems into Kubernetes Secrets. A **CNCF project**.

> **Analogy:** Instead of printing your safe combination on sticky notes (committing secrets to Git), you give each employee a badge that opens the safe — but only for the secrets they need. external-secrets-operator is the badge system.

**Problem it solves:**
- K8s Secrets are base64-encoded, not encrypted at rest by default
- Teams store secrets in Vault/cloud secret managers — need a bridge
- Avoids committing secrets to Git (even encrypted)

**Supported Backends:**
- GCP Secret Manager
- AWS Secrets Manager & Parameter Store
- Azure Key Vault
- HashiCorp Vault
- CyberArk, 1Password, Doppler, and more

**Installation:**
```bash
helm install external-secrets external-secrets/external-secrets
```

---

## external-secrets-operator - Key CRDs

| CRD | Scope | Description |
|-----|-------|-------------|
| `SecretStore` | Namespace | How to connect to a specific secret backend |
| `ClusterSecretStore` | Cluster | Same as SecretStore, accessible from any namespace |
| `ExternalSecret` | Namespace | Which secrets to fetch and how to map them |
| `ClusterExternalSecret` | Cluster | Deploy ExternalSecrets across multiple namespaces |

---

## external-secrets-operator - Example

```yaml
# ClusterSecretStore (GCP Secret Manager)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-store
spec:
  provider:
    gcpsm:
      projectID: my-gcp-project
---
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-store
    kind: ClusterSecretStore
  target:
    name: my-app-secret        # K8s Secret to create
  data:
    - secretKey: db-password    # key in K8s Secret
      remoteRef:
        key: production/db-password  # key in GCP SM
```

---

## external-secrets-operator vs Alternatives

| Approach | Pros | Cons |
|----------|------|------|
| **external-secrets-operator** | Native K8s Secrets, auto-rotation, many backends | Creates actual K8s Secrets |
| **Sealed Secrets** | GitOps-friendly, encrypted in Git | No rotation, single cluster |
| **SOPS** | Works with any tool, KMS-backed | Secrets still in Git (encrypted) |
| **CSI Secret Store Driver** | No K8s Secret created | More complex, no env var support |

---

## Reloader

**Problem:** Kubernetes does NOT restart Pods when ConfigMaps or Secrets change.

> **Note:** Volume-mounted ConfigMaps *do* eventually update on disk (kubelet syncs them periodically). However, most applications read config files once at startup and never re-read them. Environment variables **never** update without a Pod restart — they are baked in at container start time. Reloader solves this by triggering a rolling restart so the new Pod picks up the latest values.

**Solution:** Reloader watches for changes and triggers rolling restarts.

**Usage — add annotation to Deployment/StatefulSet/DaemonSet:**
```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"       # watch all referenced CMs/Secrets
    reloader.stakater.com/search: "true"     # watch CMs/Secrets with matching annotation
```

**How it works:**
- Watches ConfigMaps and Secrets for changes
- Updates a pod-template annotation to trigger a rolling restart
- Only restarts workloads that reference the changed resource

**Installation:**
```bash
helm install reloader stakater/reloader
```

**Alternative:** `kubectl rollout restart deployment/<name>` (manual)

---

## Putting It All Together

**End-to-end workflow: Deploy an app with TLS and DNS**

```
GCP Secret Manager
       │
       │  external-secrets-operator syncs credentials
       ▼
K8s Secret (db-password, api-key, ...)
       │
       │  Deployment mounts / references Secret
       ▼
Application Pods ◄─── Reloader restarts on secret rotation
       │
       │  Ingress / Gateway created with hostname
       ▼
cert-manager  ──► Let's Encrypt  ──► TLS Secret
       │
       │  Ingress/Gateway uses TLS Secret
       ▼
external-dns  ──► Cloud DNS / Route53  ──► A record: app.example.com → LB IP
       │
       ▼
https://app.example.com  ✓  (TLS auto-renewed, DNS auto-managed, secrets auto-rotated)
```

**Step by step:**
1. **external-secrets-operator** syncs database credentials from GCP Secret Manager
2. Application Deployment references the synced K8s Secret
3. **Reloader** watches for secret rotation and restarts Pods automatically
4. Ingress/Gateway created with hostname annotation
5. **cert-manager** provisions a TLS certificate from Let's Encrypt
6. **external-dns** creates a DNS A record pointing to the load balancer

**Result:** App is live at `https://app.example.com` with auto-renewed TLS — all declarative, no manual steps.

---

## Key Takeaways

- **cert-manager** automates the full TLS certificate lifecycle — issuance, storage in K8s Secrets, and renewal — using the ACME protocol (Let's Encrypt) or enterprise CAs. Always test with the **staging server** before using production to avoid rate-limit issues.
- **HTTP-01** proves domain ownership via a publicly reachable token endpoint; **DNS-01** proves it via a TXT record and is the only option for wildcard certificates.
- **external-dns** keeps DNS provider records in sync with Kubernetes resources automatically. Use `upsert-only` policy first; be careful with `sync` and broad `domainFilters` — it can delete records you didn't intend.
- **external-secrets-operator** bridges cloud secret managers (GCP SM, AWS SM, Vault) into native K8s Secrets, enabling GitOps without committing secret values.
- **Reloader** solves the Kubernetes gap where volume-mounted ConfigMaps update on disk but apps don't re-read them, and env vars never update at all — it triggers rolling restarts when referenced ConfigMaps or Secrets change.
- All four tools follow the same pattern: **CRD + Controller reconciling external state** — the Operator pattern.
- Together they deliver a fully declarative, self-healing stack: secrets synced, TLS provisioned, DNS updated, apps restarted — zero manual steps after initial configuration.

---

## Review Questions

### Beginner

1. What is the difference between an `Issuer` and a `ClusterIssuer` in cert-manager?
2. Why should you always use the Let's Encrypt staging server when testing cert-manager, before switching to the production server?
3. What is the key advantage of the DNS-01 challenge over HTTP-01, and what type of certificate does it uniquely enable?
4. What problem does external-secrets-operator solve, and why is storing secrets directly in Git considered a risk even if they are base64-encoded?
5. Why does Kubernetes NOT restart a Pod automatically when a referenced ConfigMap or Secret changes, and how does Reloader address this?

### Intermediate

1. Your team sets `policy: sync` in external-dns and uses a broad `domainFilters` of `example.com`. A colleague then deletes a Deployment. What is the risk this configuration introduces, and how would you mitigate it during an initial rollout?
2. Walk through the end-to-end flow that takes an application from zero to `https://app.example.com` — identifying exactly which platform add-on handles each step and in what order. Include the role of Workload Identity in authenticating each add-on to GCP.
