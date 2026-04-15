# Session 28 — DevSecOps & Policy Enforcement

---

## DevSecOps Overview

**Shift-Left Security:** Integrate security into every stage of the pipeline.

- Traditional: Dev → Ops → Security (security as a gate at the end)
- DevSecOps: Security embedded in Dev + Ops (continuous, automated)

**Shift-Left Analogy**

> Like an assembly line: catching a defect at the blueprint stage costs $1; at final inspection costs $100; after delivery costs $10,000.

The later in the lifecycle a vulnerability is found, the more expensive it is to fix — in engineering time, customer impact, and reputational damage. Running SAST in a pre-commit hook costs milliseconds. Responding to a breach in production costs months.

**Security Stages in Kubernetes:**

| Stage | What | Tools |
|-------|------|-------|
| **Code** | SAST, dependency scanning (SCA) | Semgrep, Snyk, Dependabot |
| **Build** | Image scanning, Dockerfile linting | Trivy, Grype, hadolint |
| **Deploy** | Admission control, policy enforcement | OPA/Gatekeeper, Kyverno |
| **Runtime** | Anomaly detection, behavioral monitoring | Falco, Tetragon |

**Key Principle:** Automate security checks — don't rely on manual review.

---

## Pipeline Security Stages Diagram

Security is not a single gate — it runs at every stage of the software delivery lifecycle:

```
Code        Build       Deploy      Runtime
 │           │           │           │
 ▼           ▼           ▼           ▼
SAST      Image Scan   Admission   Behavioral
SCA       Dockerfile   Webhooks    Monitoring
Lint      Lint         (Kyverno/   (Falco/
          (Trivy)      Gatekeeper) Tetragon)
```

Each layer catches a different class of problem:
- **Code stage** — logic flaws, known-vulnerable dependencies, hardcoded secrets
- **Build stage** — CVEs in base images, insecure Dockerfile instructions
- **Deploy stage** — policy violations before resources reach the cluster (enforcement is real-time)
- **Runtime stage** — zero-day exploits, container escapes, unexpected behavior in production

Defense-in-depth: no single layer is sufficient on its own.

---

## Image Scanning in CI

Scan container images for known vulnerabilities (CVEs) before they reach production.

**Trivy (Aqua Security — CNCF project):**
```bash
trivy image myapp:latest
trivy image --severity CRITICAL,HIGH --exit-code 1 myapp:latest
```
- Scans: OS packages, language dependencies, IaC files, secrets
- Integrates with GitHub Actions, GitLab CI, Cloud Build

**Grype (Anchore):**
```bash
grype myapp:latest
```
- Fast, focused on vulnerability scanning

**Infrastructure-as-Code Scanning:**
- **Checkov** — scans Terraform, Kubernetes YAML, Helm, Dockerfile
- **tfsec** — Terraform-specific static analysis

**Best Practice:** Block the pipeline on CRITICAL/HIGH vulnerabilities.

---

## Supply Chain Security

Ensure the integrity of artifacts from source to deployment.

**SLSA (Supply-chain Levels for Software Artifacts):**
- Framework for measuring supply chain security maturity
- Level 0: No guarantees
- Level 1: Documented build process
- Level 2: Hosted build + signed provenance
- Level 3: Hardened build platform

**Image Signing with Sigstore/cosign:**
```bash
cosign sign --key cosign.key myregistry/myapp:latest
cosign verify --key cosign.pub myregistry/myapp:latest
```
- Keyless signing with OIDC (GitHub Actions, Google Cloud)

**SBOMs (Software Bill of Materials):**
- A list of all components in a container image
- Generate with: `syft`, `trivy sbom`, `docker sbom`
- Standards: SPDX, CycloneDX

---

## Admission Controllers

A piece of code that intercepts requests to the API Server prior to persistence, after authentication and authorization.

**Two Phases:**
1. **Mutating** — modifies requests (runs first)
2. **Validating** — validates and can block a request

**Built-in Examples:**
- `DefaultIngressClass`
- `DefaultStorageClass`
- `LimitRanger` (mutating)
- `ResourceQuota` (validating)

---

## Admission Webhooks

HTTP callbacks that receive and act on API requests.

- **Mutating webhooks** — called first, can modify resources to enforce custom defaults
- **Validating webhooks** — can reject requests and enforce custom policies

This is how policy engines (OPA/Gatekeeper, Kyverno) integrate with Kubernetes.

---

## OPA / Gatekeeper

**Open Policy Agent (OPA):** General-purpose policy engine.
**Gatekeeper:** Kubernetes-native OPA integration.

- Policies written in **Rego language**
- CRDs:
  - `ConstraintTemplate` — defines the policy logic
  - `Constraint` — applies the policy to specific resources

**Example use cases:**
- Require all images from approved registries
- Block containers running as root
- Enforce resource limits on all pods
- Require specific labels on all resources

---

## Gatekeeper — Require Images from Approved Registries

A `ConstraintTemplate` defines the reusable policy logic in Rego. A `Constraint` applies it to specific resources with parameters.

```yaml
# Step 1: Define the policy logic
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requireapprovedregistry
spec:
  crd:
    spec:
      names:
        kind: RequireApprovedRegistry
      validation:
        openAPIV3Schema:
          type: object
          properties:
            allowedRegistries:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package requireapprovedregistry

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not starts_with_approved(container.image)
          msg := sprintf("Image '%v' is not from an approved registry.", [container.image])
        }

        starts_with_approved(image) {
          registry := input.parameters.allowedRegistries[_]
          startswith(image, registry)
        }
---
# Step 2: Apply the policy with allowed registry list
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequireApprovedRegistry
metadata:
  name: prod-approved-registries
spec:
  enforcementAction: deny        # block the request
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - production
      - staging
  parameters:
    allowedRegistries:
      - "us-docker.pkg.dev/my-project/"
      - "gcr.io/distroless/"
```

Test the policy without blocking first by setting `enforcementAction: dryrun` and reviewing violations with:
```bash
kubectl get requireapprovedregistry prod-approved-registries -o yaml
```

---

## Kyverno

Kubernetes-native policy engine — **no new language to learn**.

- Policies written in YAML (familiar to K8s users)
- Can: validate, mutate, generate, and clean up resources

**Example — require resource limits:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-limits
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "All containers must have CPU and memory limits"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

**Recommendation:** Kyverno for simpler adoption, OPA for complex cross-cutting logic.

---

## Runtime Security

Detect and respond to threats in running workloads.

**Falco (CNCF graduated project):**
- System call monitoring — detects anomalous behavior at runtime
- Rule-based: define expected behavior, alert on deviations
- Examples: shell spawned in container, sensitive file read, unexpected network connection
- Integrates with alerting systems (Slack, PagerDuty, etc.)

**Tetragon (by Cilium / Isovalent):**
- eBPF-based runtime security — lower overhead than Falco
- Process execution, file access, network activity monitoring
- Can **enforce** policies (kill process, block connection) — not just alert

---

## Falco — Detect Shell Spawned Inside a Container

Falco rules define what is considered normal; deviations trigger alerts. This rule fires whenever a shell binary is executed inside any running container:

```yaml
# /etc/falco/rules.d/custom-shell.yaml
- rule: Shell Spawned in Container
  desc: >
    Detect a shell (bash, sh, zsh) being spawned inside a container.
    This can indicate an attacker attempting interactive access.
  condition: >
    spawned_process
    and container
    and not container.image.repository in (known_shell_spawn_images)
    and proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name image=%container.image.repository
     shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell, mitre_execution]

# Macro and list references (typically pre-defined in Falco defaults)
- list: shell_binaries
  items: [bash, sh, zsh, ksh, fish]

- list: known_shell_spawn_images
  items: []   # add images where shell access is expected (e.g., debug toolbox)
```

Deploy Falco as a DaemonSet and route its output to your SIEM or alerting stack:
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco -n falco --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpc_output.enabled=true
```

---

## CIS Kubernetes Benchmark

- Industry-standard security checklist for Kubernetes clusters
- Covers: control plane, etcd, worker nodes, policies, network
- **Tool: kube-bench (Aqua)** — automated CIS benchmark checks

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

- GKE/EKS/AKS handle many CIS controls for managed clusters
- Focus on: workload-level controls that you own

---

## Key Takeaways

1. **Shift left saves money** — finding a vulnerability at the code stage is orders of magnitude cheaper than finding it in production; automate checks as early as possible.
2. **Admission webhooks are the enforcement layer** — Gatekeeper and Kyverno sit between `kubectl apply` and etcd; they can block non-compliant resources before they ever reach the cluster.
3. **Gatekeeper = Rego power; Kyverno = YAML simplicity** — choose based on team familiarity and policy complexity; both are production-ready.
4. **Runtime security catches what prevention misses** — zero-days and misconfigurations slip through static analysis; Falco and Tetragon provide a final detection layer in production.
5. **SBOMs and image signing close the supply chain gap** — knowing exactly what is in every image and proving it has not been tampered with is increasingly a compliance requirement.
6. **Defense-in-depth is the strategy** — no single tool covers everything; layer SAST, image scanning, admission control, and runtime monitoring for comprehensive coverage.
