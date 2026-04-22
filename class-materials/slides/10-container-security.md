# Session 10 — Container Security

---

## The Container Threat Model

A containerised app has three broad attack surfaces:

1. **The image** — vulnerable libraries, malware, leaked secrets, untrusted base
2. **The runtime** — privilege escalation, host breakout, lateral movement
3. **The supply chain** — who built this image, where did it come from, is it tampered with

A mature security program addresses all three. We'll work through each.

---

## 1. Image Security — Vulnerability Scanning

Every base image pulls in dozens to thousands of libraries. Some have known CVEs. Scanners
compare your image's package inventory against CVE databases and report findings.

### Popular scanners

| Tool | Notes |
|---|---|
| **Trivy** (Aqua) | OSS, fast, comprehensive — scans OS packages, language deps, IaC, secrets |
| **Grype** (Anchore) | OSS, works with **Syft** SBOM output |
| **Docker Scout** | Built into Docker Desktop; SaaS |
| **Snyk** | Commercial; deep language-level analysis |
| **Sysdig / Twistlock (Prisma)** | Enterprise runtime + image scanning platforms |

### Trivy quick start

```bash
# Scan an image for OS + language vulnerabilities
trivy image nginx:1.25

# Fail CI if critical/high CVEs are found
trivy image --exit-code 1 --severity CRITICAL,HIGH myapp:1.0

# Ignore specific CVEs you've assessed (with an expiry date)
cat .trivyignore
# CVE-2024-1234 exp:2026-06-01
```

### Grype + Syft

```bash
syft myapp:1.0 -o spdx-json > sbom.json
grype sbom:./sbom.json
```

### Scan early, often

Wire scanning into:

- **Dev laptops** — `trivy fs .` or IDE plugins
- **Pull requests** — block merges on new critical CVEs
- **Post-push** — registry-side scanning (GHCR, Artifact Registry, ECR all support it)
- **Runtime** — scan images in your cluster periodically; CVEs get published *after* you ship

---

## 2. Supply Chain Security — SBOMs, Signatures, Provenance

Scanning tells you *what's broken*. Supply chain controls tell you *what you're actually
running* and *where it came from*.

### SBOM — Software Bill of Materials

A machine-readable inventory of every package in an image. Two main formats:

- **SPDX** — Linux Foundation standard
- **CycloneDX** — OWASP standard

```bash
syft myapp:1.0 -o spdx-json
syft myapp:1.0 -o cyclonedx-json
```

**Why it matters:** when a new CVE drops, you need to know in minutes whether *any* of your
images contains the affected package. Grep your SBOM archive, not a thousand live
containers.

### Signing with Cosign / Sigstore

[Cosign](https://docs.sigstore.dev/cosign/overview/) signs OCI artifacts (images, SBOMs) and
stores the signatures in the registry next to the image.

```bash
# Keyless signing — short-lived cert from Fulcio, backed by OIDC identity
cosign sign ghcr.io/me/myapp:1.0

# Verify — fails if the signature isn't present / valid
cosign verify ghcr.io/me/myapp:1.0 \
  --certificate-identity "https://github.com/me/myapp/.github/workflows/release.yaml@refs/tags/v1.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

In production, Kubernetes admission policies (Kyverno, OPA/Gatekeeper) can **reject** any
unsigned image (Session 28).

### Provenance & SLSA

**SLSA** (Supply-chain Levels for Software Artifacts) — a framework with four levels of
increasing rigor: from "there's a build log" (Level 1) to "hermetic, reproducible,
non-falsifiable builds" (Level 4).

GitHub's `attest-build-provenance` and Google's Binary Authorization implement parts of
this. For now, remember: **sign what you build, verify what you run**.

---

## 3. Runtime Security — Minimise Privileges

What you can change in your Dockerfile and run commands today:

### Run as non-root

```dockerfile
RUN useradd --create-home --uid 1000 app
USER app:app
```

Or stateless:

```dockerfile
USER 1000:1000
```

Verify:

```bash
docker run --rm myapp id
# uid=1000(app) gid=1000(app)
```

### Read-only root filesystem

```bash
docker run --read-only --tmpfs /tmp --tmpfs /run myapp
```

Writes only go to the declared tmpfs mounts. Stops most persistent-payload attacks cold.

### Drop capabilities

```bash
docker run \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  nginx
```

`no-new-privileges` prevents setuid binaries from raising privilege — useful even when you
think you've dropped everything.

### Set resource limits

```bash
docker run --memory=512m --cpus=1 --pids-limit=200 myapp
```

Prevents a single container from starving the host (think fork bombs, memory leaks,
unbounded CPU).

### Never use `--privileged` or mount the Docker socket

```bash
# DANGEROUS — container can do anything the host can
docker run --privileged myapp

# Equivalent to giving the container root on the host
docker run -v /var/run/docker.sock:/var/run/docker.sock myapp
```

Both are routine breakout vectors. If you think you need the socket (e.g., for a CI
runner), look at **rootless Docker**, **Kaniko**, or **sysbox** first.

---

## 4. Trusted & Minimal Base Images

Fewer packages → fewer CVEs → smaller attack surface.

| Base | Typical size | Shell? | Package manager? |
|---|---|---|---|
| `ubuntu:22.04` | ~80 MB | Yes | apt |
| `debian:bookworm-slim` | ~75 MB | Yes | apt |
| `alpine:3.19` | ~5 MB | Yes (ash) | apk |
| `gcr.io/distroless/base` | ~20 MB | **No** | **No** |
| `gcr.io/distroless/static:nonroot` | ~2 MB | No | No | 
| `chainguard/static` | ~1–10 MB | No | No |
| `scratch` | 0 MB | No | No |

**Prefer distroless / Chainguard for production runtime images** — without a shell and
package manager, most "drop a shell and install tools" attacks are impossible.

---

## 5. Secrets Management

Rule one: **never** bake secrets into images. Not as `ARG`s, not as `ENV`, not in files you
COPY in.

### Build-time secrets — BuildKit

```dockerfile
# syntax=docker/dockerfile:1.7
FROM alpine
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) \
    npm install ...
```

```bash
docker build --secret id=npm_token,env=NPM_TOKEN -t myapp .
```

Never lands in a layer; never in `docker history`.

### Runtime secrets

- **Docker Secrets** — ships with Swarm; mounts files under `/run/secrets/<name>`
- **Environment variable from a secrets manager** — inject at run time from Vault, AWS
  Secrets Manager, GCP Secret Manager
- **Kubernetes Secrets** — Session 15; paired with external-secrets-operator (Session 19)
  for production

Never `-e DB_PASSWORD=…` on a shared host — it's visible in the process list.

---

## 6. The Big Defaults: Linux Security Features

(Covered in Session 9 — here's the security recap.)

| Feature | What it stops |
|---|---|
| **Namespaces** | Seeing other processes, networks, mounts, PIDs |
| **cgroups** | Resource exhaustion DoS |
| **Capabilities** | Unnecessary privileged operations |
| **Seccomp** | Dangerous syscalls (mount, reboot, kexec, etc.) |
| **AppArmor / SELinux** | Broad file / operation misuse |
| **User namespaces** | Container root being host root |

Docker's defaults are decent — but opt in to the extras for hardened workloads.

---

## 7. CIS Docker Benchmark

The [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) is a checklist of
~100 recommendations for hardening a Docker host and its containers. Representative items:

- Host: audit daemon config, restrict socket permissions, enable remote logging
- Daemon: `live-restore`, `no-new-privileges`, userns-remap, content trust
- Images: pin base, multi-stage, non-root, healthcheck, label with OCI metadata
- Containers: drop capabilities, read-only rootfs, resource limits, no host namespaces

Check your hosts with [Docker Bench for Security](https://github.com/docker/docker-bench-security):

```bash
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

Treat it as a guide, not a must-pass checklist — some items are noise for cloud-managed
hosts.

---

## 8. A Production-Ready Dockerfile (Security Edition)

```dockerfile
# syntax=docker/dockerfile:1.7

FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

And the run command:

```bash
docker run -d --name app \
  --read-only \
  --tmpfs /tmp:size=32m \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory=256m --cpus=1 \
  --pids-limit=200 \
  -p 8080:8080 \
  myapp:1.0
```

---

## 9. Runtime Anomaly Detection (Preview)

Scanning tells you about CVEs in what you shipped. **Runtime security** tools watch
containers while they run and alert on suspicious behaviour:

- **Falco** (CNCF) — eBPF-based syscall monitoring; rule-driven alerts
- **Tetragon** (Isovalent / Cilium) — eBPF; fine-grained process + network observability
- **Sysdig Secure** — commercial; combines Falco + posture management

Detect: a shell spawned inside a web server, a process reading `/etc/shadow`, a container
loading a kernel module. Session 28 goes deeper.

---

## 10. A Security Checklist for Every Image

- [ ] Pin the base image (digest or specific tag — never `latest`)
- [ ] Use a minimal base (distroless / Chainguard / Alpine)
- [ ] Multi-stage builds — no compilers in the runtime image
- [ ] `USER` non-root — never UID 0
- [ ] Drop capabilities (`--cap-drop=ALL`) and add back only what you need
- [ ] Read-only root filesystem + tmpfs for writable scratch
- [ ] `no-new-privileges` at run time
- [ ] Memory, CPU, PID limits
- [ ] No secrets in `ARG` / `ENV` / `COPY` — use BuildKit secrets or runtime injection
- [ ] Scan with Trivy/Grype in CI; fail on HIGH/CRITICAL
- [ ] Generate and archive an SBOM (Syft)
- [ ] Sign with Cosign; verify on deploy
- [ ] Healthcheck defined
- [ ] OCI labels for source, version, and licence

---

## Key Takeaways

- Image security, runtime security, and supply chain security are **three separate problems**
- **Scan** (Trivy), **SBOM** (Syft), **sign** (Cosign), **verify** (Kyverno / admission) —
  this is the modern chain
- Default to **distroless + non-root + read-only + cap-drop ALL** for production containers
- **Never** `--privileged`; **never** mount the Docker socket; **never** bake secrets
- cgroup-based resource limits are a **security control**, not just an efficiency one
- Pair image scanning with **runtime detection** (Falco, Tetragon) for defense-in-depth

---

## Review Questions

### Beginner

1. Name two tools for scanning a container image for vulnerabilities.
2. What's the difference between an SBOM and a vulnerability scan?
3. Why should containers run as a non-root user?
4. What does `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` mean?
5. Why is mounting `/var/run/docker.sock` into a container dangerous?

### Intermediate

1. Your registry reports 0 CVEs on your latest image. Three days later, it reports 12
   criticals. Nothing changed in your image. Explain why, and describe how SBOM + continuous
   scanning would have caught the older issues sooner.
2. A vendor delivers an image that requires `--privileged`. Walk through how you'd use
   `strace`, `capsh`, and seccomp audit logs to figure out the actual minimum it needs.
3. Map each Dockerfile-level and runtime-level hardening control from this session onto its
   Kubernetes equivalent (Pod Security Standards, `securityContext`, admission policies).
   Where does Kubernetes add protections that plain Docker can't offer?
