# Docker Fundamentals

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Why This Matters

Before you can understand Kubernetes, you need to understand what Kubernetes is actually orchestrating: **containers**. Docker is the most widely-used container runtime and toolchain, and the concepts you learn here — images, layers, registries, the OCI standard — are the foundation everything else is built on. Kubernetes itself is container-runtime-agnostic, but the mental model you build with Docker translates directly to how Kubernetes pulls images, runs workloads, and manages container lifecycles.

Understanding Docker deeply also helps you write better Kubernetes manifests, debug failing pods, and have meaningful conversations about image security, build pipelines, and registry architecture. Sessions 1–5 of this course build the container foundation you'll rely on throughout the entire program.

---

## 🎥 YouTube Videos

### Docker in 100 Seconds
[![Thumbnail](https://img.youtube.com/vi/Gjnup-PuquQ/0.jpg)](https://www.youtube.com/watch?v=Gjnup-PuquQ)
**Channel:** Fireship
> A fast, visual 100-second explainer on what Docker is and why it matters — perfect first watch before diving deeper.

### Docker Tutorial for Beginners (Full Course)
[![Thumbnail](https://img.youtube.com/vi/3c-iBn73dDE/0.jpg)](https://www.youtube.com/watch?v=3c-iBn73dDE)
**Channel:** TechWorld with Nana
> Comprehensive 3-hour Docker beginner course covering installation, commands, images, Dockerfile, Docker Compose, and a real-world project.

### Docker Architecture Deep Dive
[![Thumbnail](https://img.youtube.com/vi/RqTEHSBrYFw/0.jpg)](https://www.youtube.com/watch?v=RqTEHSBrYFw)
**Channel:** KodeKloud
> Explains containerd, runc, and the OCI stack beneath Docker — essential background for understanding how containers actually start.

### Multi-Stage Docker Builds
[![Thumbnail](https://img.youtube.com/vi/zpkqNPwEzac/0.jpg)](https://www.youtube.com/watch?v=zpkqNPwEzac)
**Channel:** TechWorld with Nana
> Practical guide to multi-stage builds — how to produce small, production-ready images by separating build from runtime stages.

---

## 📚 Articles & Documentation

### Docker Overview
🔗 [Docker Overview](https://docs.docker.com/get-started/overview/)
**Source:** Docker Official Docs | **Level:** Beginner
> The official Docker architecture overview — covers daemon, client, registries, images, and containers.

### OCI Image Specification
🔗 [OCI Image Spec](https://github.com/opencontainers/image-spec)
**Source:** Open Container Initiative | **Level:** Intermediate
> The open standard that defines what a container image is — relevant for understanding why images work across different runtimes.

### Docker vs Virtual Machines
🔗 [Containers vs VMs](https://www.docker.com/resources/what-container/)
**Source:** Docker | **Level:** Beginner
> Side-by-side comparison of containers and VMs — share the host kernel, start in milliseconds, and are far more lightweight.

### Dockerfile Reference
🔗 [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
**Source:** Docker Official Docs | **Level:** Intermediate
> Complete reference for every Dockerfile instruction — bookmark this and refer back often.

---

## Key Concepts

### Why Docker? The Dependency Hell Problem

Before containers, deploying an application meant wrestling with dependency conflicts: "it works on my machine" was a universal complaint. A Python 2.7 app couldn't live peacefully alongside a Python 3.9 app without virtualenvs or careful isolation. Libraries conflicted. System packages differed between dev, staging, and prod.

Docker solves this by **packaging the application together with all its dependencies** into a single, portable unit — a container image. You build it once, and it runs identically everywhere: your laptop, a CI server, a Kubernetes node in the cloud.

### Virtual Machines vs. Containers

| Aspect | Virtual Machine | Container |
|--------|----------------|-----------|
| Isolation unit | Full OS + kernel | Process namespace |
| Size | GBs | MBs |
| Startup time | Minutes | Milliseconds |
| Overhead | High (hypervisor) | Low (shared kernel) |
| Use case | Strong isolation, different OS | Application packaging |

Containers are **not** VMs. They share the host kernel. Each container is really just a process (or group of processes) with namespaces and cgroups applied to it — more on this in Sessions 9-10.

### The OCI Standard

The [Open Container Initiative (OCI)](https://opencontainers.org/) defines two key specs:
- **Image Spec**: What a container image looks like (layers, manifests, config JSON)
- **Runtime Spec**: How a container runtime should start/stop containers

This means images built with Docker can run with `containerd`, `podman`, or any OCI-compliant runtime — including Kubernetes's default runtime (containerd).

### Docker Desktop vs Docker Engine

- **Docker Desktop**: The GUI application for Mac/Windows. Runs a lightweight Linux VM under the hood. Includes Docker Engine, Docker CLI, Docker Compose, and BuildKit. Great for development.
- **Docker Engine**: The daemon + CLI for Linux. Used in production, CI/CD, and on Kubernetes nodes (via containerd underneath).

### Docker Architecture

```
┌─────────────────────────────────────┐
│         Docker Client (CLI)         │
│         docker run / build / push   │
└──────────────┬──────────────────────┘
               │ REST API (Unix socket)
┌──────────────▼──────────────────────┐
│         Docker Daemon (dockerd)     │
│   Manages images, containers,       │
│   networks, volumes                 │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         containerd                  │
│   Container lifecycle management    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         runc                        │
│   OCI runtime — actually creates    │
│   the container process             │
└─────────────────────────────────────┘
```

Key insight: `dockerd` talks to `containerd`, which uses `runc` to create container processes. Kubernetes bypasses `dockerd` entirely and talks directly to `containerd`.

### Image Layers and OverlayFS

Docker images are **layered**. Each instruction in a Dockerfile creates a new read-only layer. When you run a container, Docker adds a thin writable layer on top. This is implemented using **OverlayFS** (or other storage drivers).

```
Layer 4 (writable):  Your running container changes
Layer 3 (read-only): COPY . /app
Layer 2 (read-only): RUN pip install -r requirements.txt
Layer 1 (read-only): FROM python:3.11-slim
```

**Copy-on-write**: When a container modifies a file from a read-only layer, OverlayFS copies it to the writable layer first. The original layer is never modified. This is why 10 containers based on the same image don't each use 500MB of disk — they share the read-only layers.

### Running Containers

Key `docker run` options:
```bash
docker run   --name my-app \           # container name
  -d \                      # detach (run in background)
  -p 8080:80 \              # host_port:container_port
  -e APP_ENV=production \   # environment variable
  --restart unless-stopped \# restart policy
  --memory 512m \           # memory limit
  --cpus 0.5 \              # CPU limit
  nginx:1.25
```

**Container lifecycle**: created → running → paused/stopped → removed

**Useful runtime commands**:
```bash
docker logs -f my-app          # stream logs
docker exec -it my-app bash    # interactive shell
docker inspect my-app          # full JSON metadata
docker stats                   # live resource usage
docker top my-app              # processes inside container
```

**Restart policies**: `no` | `always` | `unless-stopped` | `on-failure[:max-retries]`

### Images Deep Dive

**Image anatomy**: An image consists of:
1. **Config JSON** — environment variables, entry point, exposed ports, architecture
2. **Layers** — compressed tar archives of filesystem diffs
3. **Manifest** — JSON listing the config and layer digests

**Tags vs Digests**:
```bash
nginx:1.25              # tag (mutable — can be overwritten)
nginx@sha256:abc123...  # digest (immutable — tied to exact content)
```

In production, prefer digests or pinned tags over `latest`.

**Multi-stage builds** keep images small:
```dockerfile
# Stage 1: Build
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o server .

# Stage 2: Runtime (tiny!)
FROM gcr.io/distroless/static
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

**Registries**: Docker Hub, Google Container Registry (GCR), Amazon ECR, Azure ACR, GitHub Container Registry (GHCR). In Kubernetes, `imagePullSecrets` provide credentials to pull from private registries.

### Dockerfile Best Practices

**Layer caching**: Docker caches each layer. Put instructions that change rarely (installing OS packages) before instructions that change often (copying your code). This makes rebuilds fast.

```dockerfile
# Good: dependencies before source code
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .                       # cache miss here, but deps are cached

# Bad: one big layer, no caching benefit
COPY . .
RUN pip install -r requirements.txt
```

**Minimal base images**:
- `scratch` — empty image, for statically compiled binaries only
- `alpine` — ~5MB, musl libc, good for many languages
- `distroless` (Google) — no shell, minimal attack surface, language-specific variants
- `debian-slim` / `ubuntu` — larger but compatible with most software

**ARG vs ENV**:
- `ARG` — available only during build (docker build --build-arg)
- `ENV` — persisted in the image and available at runtime

**COPY vs ADD**:
- `COPY` — simple, predictable, copies local files only ✅
- `ADD` — also extracts tar archives and fetches URLs — surprising behavior, avoid unless needed

**ENTRYPOINT vs CMD**:
- `ENTRYPOINT` — the executable that always runs
- `CMD` — default arguments to ENTRYPOINT (easily overridden)
- Use exec form (`["executable", "arg"]`) not shell form (`executable arg`) — exec form ensures signals reach your process

**BuildKit**: Docker's modern build engine. Enable with `DOCKER_BUILDKIT=1`. Features: parallel stages, build secrets (never leak into layers), SSH forwarding, better caching.

**hadolint**: Dockerfile linter. Catches common mistakes and anti-patterns. Run `docker run --rm -i hadolint/hadolint < Dockerfile`.

---

## Key Concepts to Know Before Class

- Explain the problem containers solve and why VMs aren't always the right tool
- Describe the Docker architecture: client → daemon → containerd → runc
- What is the OCI standard and why does it matter?
- What are image layers? How does OverlayFS / copy-on-write work?
- Explain the difference between an image and a container
- What does `docker run -d -p 8080:80 --restart unless-stopped nginx` do, option by option?
- How do you view logs, open a shell, and inspect resource usage for a running container?
- What is a multi-stage build and why is it useful?
- What's the difference between a tag and a digest? Which is more reliable in production?
- What are image registries? Name three besides Docker Hub.
- Explain the difference between ENTRYPOINT and CMD
- Why does layer ordering matter in a Dockerfile?
- What are distroless images? Why use them?
- What is BuildKit and what advantages does it provide?

---

## Hands-On Before Class (Optional)

1. **Install Docker Desktop** on your machine: [docs.docker.com/get-docker](https://docs.docker.com/get-docker/)
2. **Run your first container**: `docker run hello-world`
3. **Explore an image**: `docker run -it --rm alpine sh` — poke around, then exit
4. **Write a simple Dockerfile**: Create a Dockerfile that runs a Python "Hello World" web server with Flask. Build it and run it.
5. **Inspect layers**: Run `docker history <image>` on an image you've built to see the layers and sizes.
6. **Practice multi-stage**: Take a compiled language app (Go or Java) and create a multi-stage Dockerfile to produce a minimal image.
7. **Compare sizes**: Build the same app with `ubuntu` as base, then with `alpine`, then distroless. Compare `docker images` output.
8. **Lint your Dockerfile**: Run hadolint on your Dockerfile and fix any warnings.
