# Session 4 — Images Deep Dive

---

## What is an Image, Really?

An image is **files + metadata**, packaged in the OCI image format:

- A set of **layers** — tar archives of filesystem diffs
- A **config blob** — JSON describing env vars, entrypoint, working dir, exposed ports, author
- A **manifest** — JSON that points to the config and lists the layer digests
- For multi-arch images: a **manifest list** (index) that maps platforms (linux/amd64,
  linux/arm64) to manifests

Every object is content-addressed by a SHA-256 digest — change any byte and the digest changes.

```
manifest (or manifest list for multi-arch)
 ├── config blob  ─── env, entrypoint, layer order
 └── layers[]
      ├── sha256:a1b2…   (base filesystem)
      ├── sha256:c3d4…   (apt packages)
      └── sha256:e5f6…   (app code)
```

---

## Layers, Digests, and Tags

- **Layer** — a read-only diff produced by one build step
- **Digest** — a SHA-256 over the content (`sha256:a1b2…`); immutable
- **Tag** — a mutable human-friendly label (`python:3.11`, `myapp:v1.2.3`)
- **Repository** — a named collection of images (`library/python`)

One image → one digest. One digest → potentially many tags.

```bash
docker image ls --digests python
# python    3.11    sha256:a1b2…   2 weeks ago   1.01GB
# python    latest  sha256:a1b2…   2 weeks ago   1.01GB
```

**Pin to digests in production:**

```yaml
image: python@sha256:a1b2c3d4…
```

This guarantees the bytes you deployed yesterday are the bytes running today, even if
someone moves the tag.

---

## Inspecting an Image

```bash
docker image pull nginx:1.25

# All images on disk
docker image ls

# History — one line per layer, with the instruction that created it
docker image history nginx:1.25
docker image history --no-trunc nginx:1.25

# Full JSON config
docker image inspect nginx:1.25

# Specific fields
docker image inspect -f '{{.Config.Entrypoint}}' nginx:1.25
docker image inspect -f '{{.RootFS.Layers}}' nginx:1.25
```

---

## Building Images: `docker build`

Two ways to produce an image:

1. **`docker container commit`** — snapshot a running container. Quick for prototyping; not
   reproducible; avoid in production.
2. **`docker image build`** — execute a `Dockerfile`. Reproducible, versionable, diff-able.
   **Always prefer this.**

```bash
docker image build -t myapp:1.0 .
docker image build -t myapp:1.0 -f Dockerfile.prod .
docker image build -t myapp:1.0 --platform=linux/amd64,linux/arm64 --push .
```

---

## The Build Context

The final `.` in `docker build … .` is the **build context** — the daemon tars up that
directory and sends it over the Docker API. The Dockerfile can only `COPY` files from inside
the context.

**Why this matters:**

- A context of 2 GB takes seconds to transfer even on localhost
- Accidentally including `node_modules/`, `.git/`, or big media files bloats every build
- The context is visible in the daemon; don't include secrets

---

## `.dockerignore`

Exclude files from the context. Same syntax as `.gitignore`:

```
.git
.gitignore
node_modules
__pycache__
*.log
.env
.env.*
Dockerfile
README.md
```

Check your context size:

```bash
docker build . 2>&1 | grep "transferring context"
```

---

## Multi-Stage Builds (Intro — deep dive in Session 5)

Build tools (compilers, JDKs, dev dependencies) don't belong in the runtime image.

```dockerfile
# ── Stage 1: build ─────────────────────────────
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN go build -o /app ./cmd/server

# ── Stage 2: runtime (tiny) ────────────────────
FROM gcr.io/distroless/static:nonroot
COPY --from=build /app /app
ENTRYPOINT ["/app"]
```

Final image ships a few MB, not 800 MB — and carries no compiler to exploit.

---

## Container Registries

A **registry** is an HTTP service implementing the OCI distribution spec. It stores images
and serves layers by digest.

| Registry | Hostname | Notes |
|---|---|---|
| **Docker Hub** | `docker.io` | Default; rate-limited for anonymous pulls |
| **GHCR** | `ghcr.io` | GitHub Container Registry |
| **Google Artifact Registry** | `<region>-docker.pkg.dev` | GCP |
| **ECR** | `<account>.dkr.ecr.<region>.amazonaws.com` | AWS |
| **ACR** | `<name>.azurecr.io` | Azure |
| **Harbor** | self-hosted | Open-source, popular in enterprises |

**Image namespaces:**

- `nginx` — short form for `docker.io/library/nginx` (official)
- `bitnami/postgresql` — `docker.io/bitnami/postgresql` (user/org namespace)
- `gcr.io/project-id/service` — self-hosted / cloud registry

---

## Pushing and Pulling

```bash
# Log in — writes creds to ~/.docker/config.json
docker login                           # Docker Hub
docker login ghcr.io                   # GHCR
gcloud auth configure-docker us-docker.pkg.dev

# Tag a local image to match the target repository
docker image tag myapp:1.0 ghcr.io/my-org/myapp:1.0

# Push
docker image push ghcr.io/my-org/myapp:1.0

# Pull a specific digest
docker image pull nginx@sha256:a1b2…

# Pull a specific platform (multi-arch)
docker image pull --platform=linux/arm64 nginx:1.25
```

---

## Tagging Strategies

**The `latest` trap:**

- `latest` is just a tag like any other; **not** "the newest"
- It moves — what worked yesterday may be different today
- In production manifests, `latest` is a deploy-time lottery

**Better patterns:**

| Scheme | Example | When |
|---|---|---|
| **Semver** | `myapp:1.4.2` | Released libraries, stable services |
| **Git SHA** | `myapp:git-a1b2c3d` | Every build, traceable to a commit |
| **Date** | `myapp:2026-01-15` | Nightly builds |
| **Digest pin** | `myapp@sha256:…` | Production deploys, reproducibility |
| **Combined** | `myapp:1.4.2-a1b2c3d` | Best of both — readable + unique |

**Rule of thumb:** CI produces immutable tags (SHA, digest). Humans reference semver.
Deploys pin to digests.

---

## Authentication and Private Registries

```bash
# Stored credentials
cat ~/.docker/config.json

# Credentials helpers (recommended) — store in OS keychain
docker-credential-osxkeychain list
```

**In Kubernetes:** a registry secret is mounted via `imagePullSecrets` on the Pod spec or
service account. We'll cover this in Session 15.

**In CI/CD:** short-lived tokens from OIDC / Workload Identity beat long-lived service-account
keys. GitHub Actions → GHCR, Cloud Build → Artifact Registry, and similar cloud integrations
avoid ever creating a static password.

---

## Image Pull Policies

Both Docker and Kubernetes decide when to pull from the registry vs use a local copy.

| Policy | Behaviour |
|---|---|
| `always` | Pull every time |
| `missing` / `IfNotPresent` | Pull only if not cached locally (k8s default for non-`:latest`) |
| `never` | Never pull — must exist locally |

**Pitfall:** In Kubernetes, `image: myapp:latest` defaults to `imagePullPolicy: Always`,
while a tagged image defaults to `IfNotPresent`. Pinning to a digest avoids both surprises.

---

## Image Size Matters

Smaller images:

- Pull faster → faster cold starts, faster scale-outs
- Have a smaller attack surface (fewer CVEs)
- Cost less in storage and egress

**Base image ladder (from big to tiny):**

| Base | Typical size | Tradeoffs |
|---|---|---|
| `ubuntu:22.04` | ~80 MB | Familiar; full package manager |
| `debian:bookworm-slim` | ~75 MB | Good default for glibc apps |
| `python:3.11` | ~1 GB | Full toolchain; huge |
| `python:3.11-slim` | ~150 MB | Debian slim + Python; usually enough |
| `python:3.11-alpine` | ~55 MB | musl libc — some wheels won't install |
| `gcr.io/distroless/python3` | ~50 MB | No shell, no package manager |
| `scratch` | 0 MB | Empty; only for fully static binaries |

---

## Versioning: Semantic vs Calendar

**Semantic Versioning (SemVer) — `MAJOR.MINOR.PATCH`:**

- `MAJOR` — breaking changes
- `MINOR` — backwards-compatible features
- `PATCH` — backwards-compatible bug fixes
- Used by Kubernetes, most libraries

**Calendar Versioning (CalVer) — `YYYY.MM.PATCH`:**

- `2024.04.0`, `2024.04.1`
- Used by Ubuntu (`22.04`), Terraform, and many SaaS products
- Makes "how old is this?" instantly readable

Pick one per product and stick with it.

---

## Multi-Architecture Images

`docker buildx` + BuildKit builds for multiple CPU architectures in one go. A **manifest
list** maps each platform to its per-arch image:

```bash
# One-time setup
docker buildx create --name multi --use

# Build and push linux/amd64 + linux/arm64 in one command
docker buildx build \
  --platform=linux/amd64,linux/arm64 \
  -t ghcr.io/my-org/myapp:1.0 \
  --push .
```

Pulling on an Apple Silicon laptop (arm64) gets the arm64 variant; on a GKE amd64 node, the
amd64 variant — same tag, right bytes.

---

## Key Takeaways

- Images are **layered, content-addressed bundles** — a manifest + config + layer digests
- `docker build` is reproducible; `docker commit` is a last resort
- Mind your **build context** — use `.dockerignore` to keep it small
- **Multi-stage builds** separate build-time and runtime images
- Tag with semver + git SHA; **pin to digests** for production deploys
- Smaller base images = faster pulls, smaller attack surface
- Use `buildx` for multi-arch; deploy the same tag to mixed-arch fleets

---

## Review Questions

### Beginner

1. What is the difference between an image **tag** and a **digest**?
2. What is the "build context," and why does its size matter?
3. Name two base image families and when you'd choose each.
4. Why is tagging images as `:latest` risky for production?
5. What is the `.dockerignore` file for?

### Intermediate

1. Your production deploy uses `image: myapp:prod`. The same tag has been pushed three times
   today. A Pod restart picks up a new version and the app crashes. Walk through how this
   happened and what you'd change to prevent it.
2. An engineer's `docker build` takes 15 minutes and transfers 4 GB of context. What are the
   likely causes, and what would you measure/change to fix it?
3. Your team runs Apple Silicon laptops locally and amd64 in production. Tests pass on
   laptops, the pod CrashLoopBackOffs in prod. What's the probable cause and the fix?
