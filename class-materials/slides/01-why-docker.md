# Session 1 — Why Docker + Containers vs VMs

---

## Why Containers?

Software used to ship as a binary + a long README of prerequisites. Running it reliably on a
different machine was a gamble — a different OS version, missing library, or conflicting
dependency would break it.

Containers fix this by shipping the application **and** everything it depends on as a single
portable unit.

- **Ease of use** — `docker run` replaces a 40-step setup guide
- **Isolated processes** — each container has its own filesystem, process tree, and network
- **Non-interference** — two apps that need different versions of the same library can coexist
- **Dev/prod parity** — the image you test locally is the exact same image that runs in prod

---

## The Problem Docker Solves

> "It works on my machine."

Common failure modes before containers:

- Dev uses Python 3.11, staging has 3.9, prod has 3.8 → subtle bugs only appear in prod
- New engineer spends 2 days getting the app running locally
- Two services on the same VM fight over port 8080
- One app upgrades a shared library and breaks three others
- CI agents drift from production — tests pass, deploys fail

Containers collapse the gap between environments by bundling the runtime, libraries, and
config together.

---

## What is a Container?

**Definition:**
A container is a sandboxed process on a host machine that is isolated from all other
processes on the same host. It is a **runnable instance of an image**.

- Ships with its own root filesystem (libraries, binaries, config)
- Shares the host's Linux kernel — does not boot its own OS
- Starts in milliseconds
- Uses only the resources the workload actually needs (no guest OS tax)

**Three things you need to work with containers:**

1. A **builder** — a tool that produces container images (e.g., `docker build`, BuildKit, Buildah)
2. An **engine** — a runtime that executes containers (e.g., Docker Engine, containerd, Podman)
3. An **orchestrator** — a system that runs many containers across many hosts (Kubernetes, Nomad)

---

## Virtual Machines vs Containers

```
┌─────────────────────────────┐   ┌─────────────────────────────┐
│  App A     │ App B   │ App C│   │  App A   │  App B  │ App C  │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Libs A     │ Libs B  │ Libs │   │Libs A    │ Libs B  │ Libs C │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Guest OS   │Guest OS │Guest │   │                             │
├─────────────────────────────┤   │      Container Engine       │
│         Hypervisor          │   ├─────────────────────────────┤
├─────────────────────────────┤   │        Host Kernel          │
│         Host OS             │   ├─────────────────────────────┤
├─────────────────────────────┤   │         Hardware            │
│         Hardware            │   │                             │
└─────────────────────────────┘   └─────────────────────────────┘
        Virtual Machines                  Containers
```

| Dimension | Virtual Machine | Container |
|---|---|---|
| **Isolation** | Full hardware virtualization | Kernel-level process isolation (namespaces + cgroups) |
| **Guest OS** | Yes — full OS per VM | No — shares host kernel |
| **Boot time** | Seconds to minutes | Milliseconds |
| **Image size** | GBs | MBs (often < 100 MB) |
| **Density** | 10s per host | 100s–1000s per host |
| **Security boundary** | Strong (hypervisor) | Weaker (kernel shared) — mitigated with gVisor, Kata, user namespaces |

**Both have a place** — VMs for strong isolation between tenants, containers for application
packaging and density. Modern clouds run containers *inside* VMs to get the best of both.

---

## Container Use Cases

- **Microservices** — each service ships as its own image, scales independently
- **CI/CD** — every pipeline step runs in a clean, reproducible container
- **Developer environments** — `docker compose up` spins up your full stack locally
- **Batch jobs** — run a job, exit, get resources back (CronJobs, Argo Workflows)
- **Legacy lift-and-shift** — containerize a monolith to get dev/prod parity without rewriting it
- **Desktop apps** — editors, AI tools, internal tooling shipped as containers

---

## Monoliths vs Microservices

Containers don't force microservices — but they make microservices practical.

**Monolith:**

- Pros: simple to develop, test, deploy; one process, one repo, one deploy
- Cons: redeploy the whole app for any change; scales as a single unit; one bug can take everything down

**Microservices:**

- Pros: deploy services independently; scale hot paths only; polyglot (different languages per service)
- Cons: complex networking; distributed debugging; operational burden; eventual consistency

> **Rule of thumb:** start with a monolith. Extract services only when team size, scaling
> needs, or deployment cadence demand it. Containers make either choice viable.

---

## The OCI Standard — Why Docker Is Not the Only Game

The **Open Container Initiative** (OCI) is a Linux Foundation project that standardizes:

1. **Image spec** — the format of a container image (layers, manifest, config)
2. **Runtime spec** — how to unpack and run a container from an image
3. **Distribution spec** — how registries serve images over HTTP

Because of OCI, you can:

- Build an image with Docker, run it with containerd, Podman, or CRI-O
- Push it to Docker Hub, GCR, ECR, ACR, GHCR, or Harbor — same format everywhere
- Kubernetes talks to any OCI-compliant runtime via the Container Runtime Interface (CRI)

**Key OCI-compliant tools:**

| Role | Examples |
|---|---|
| Builders | Docker (BuildKit), Buildah, Kaniko, ko |
| Runtimes | containerd, CRI-O, runc, crun |
| CLIs | docker, podman, nerdctl |
| Registries | Docker Hub, Artifact Registry (GCP), ECR (AWS), ACR (Azure), Harbor |

---

## Docker Desktop vs Docker Engine

**Docker Engine** — the open-source daemon (`dockerd`) + CLI. Runs natively on Linux.

**Docker Desktop** — a commercial product that wraps Docker Engine with:

- A lightweight Linux VM (on macOS/Windows) so the engine has a Linux kernel to use
- A graphical UI for images, containers, volumes
- A built-in single-node Kubernetes cluster
- Extensions, Docker Scout (vulnerability scanning), Compose integration

**When to use which:**

| Use case | Tool |
|---|---|
| Linux server, CI agent, headless | Docker Engine (`get.docker.com` script) |
| macOS or Windows developer laptop | Docker Desktop, Rancher Desktop, or Podman Desktop |
| Corporate/air-gapped environments | Engine + custom scripts, or Podman |

> Docker Desktop is **free for personal/educational use and small businesses**, but requires
> a paid license for larger organizations. Check current terms before corporate rollout.

---

## Pets vs Cattle

A useful metaphor for how containers change operations:

| Pets | Cattle |
|---|---|
| Unique names (`db-prod-01`) | Generic IDs (`web-7f3c9a`) |
| Hand-configured, hand-fixed | Identical, disposable |
| Outage → you SSH in and fix | Outage → replace it |
| Scale up = bigger server | Scale out = more instances |

Containers (and Kubernetes) push you firmly into the **cattle** model — if a container is sick,
kill it and start another. This is only possible because the container is reproducible
from its image.

---

## Key Takeaways

- Containers package an app and its dependencies into a **portable, reproducible unit**
- They are **processes with isolation** — not mini VMs — and rely on the host kernel
- VMs give stronger isolation; containers give density, speed, and dev/prod parity
- The **OCI standard** means tooling is interchangeable — you are not locked into Docker
- **Docker Engine** runs containers; **Docker Desktop** adds a VM + UI for macOS/Windows
- Treat containers like **cattle, not pets** — build to replace, not to repair

---

## Review Questions

### Beginner

1. What problem do containers solve that a tarball + README does not?
2. Name two things a VM has that a container does not.
3. What does OCI stand for, and why does it matter?
4. Why does a container start in milliseconds but a VM takes seconds or minutes?
5. What is the difference between Docker Engine and Docker Desktop?

### Intermediate

1. Your team has a Python service that works on developer laptops but crashes in production.
   How could containers have prevented this, and which specific environment differences would
   they eliminate?
2. A colleague argues that containers provide "the same isolation as VMs." What would you
   push back on, and in what scenarios would you still want a VM?
3. When would you choose Podman over Docker, and when would that choice be invisible to the
   rest of your tooling?
