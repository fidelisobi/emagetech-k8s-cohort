# Session 2 — Docker Architecture

---

## Docker is a Client-Server Application

The `docker` command you type is **not** the thing that runs containers. It is a thin CLI
that talks to a long-running daemon.

```
┌──────────────┐          REST / gRPC           ┌────────────────────────┐
│  docker CLI  │ ──────────────────────────────► │   dockerd (daemon)     │
│  (client)    │   /var/run/docker.sock          │                        │
└──────────────┘   or TCP                        │  ┌──────────────────┐  │
                                                 │  │   containerd     │  │
                                                 │  │  ┌────────────┐  │  │
                                                 │  │  │ containerd │  │  │
                                                 │  │  │ -shim      │  │  │
                                                 │  │  │  ┌──────┐  │  │  │
                                                 │  │  │  │ runc │  │  │  │
                                                 │  │  │  └───┬──┘  │  │  │
                                                 │  │  └──────┼─────┘  │  │
                                                 │  └─────────┼────────┘  │
                                                 └────────────┼───────────┘
                                                              ▼
                                                       ┌──────────────┐
                                                       │   container  │
                                                       │   (process)  │
                                                       └──────────────┘
```

The four pieces:

1. **Docker Client (`docker`)** — CLI that sends API requests
2. **Docker Daemon (`dockerd`)** — long-running server that manages images, containers,
   networks, volumes; exposes the REST API
3. **containerd** — the actual container lifecycle manager (start, stop, pull images)
4. **runc** — the low-level tool that creates the container process using Linux primitives

---

## The Docker Engine

**Docker Engine** = `dockerd` + `docker` CLI + the REST API that connects them.

- By default the daemon listens on a **Unix socket** at `/var/run/docker.sock`
- The client can also talk to a remote daemon over TCP (`DOCKER_HOST=tcp://host:2376`)
- Anything you can do with the CLI, you can do with a `curl` call to the API
- Membership in the `docker` group (on Linux) is effectively **root** — the daemon runs as root

```bash
# Show daemon version, API version, and build info
docker version

# Full daemon config, storage driver, kernel details
docker info

# Hit the REST API directly
curl --unix-socket /var/run/docker.sock http://localhost/v1.43/containers/json
```

---

## What Each Layer Actually Does

**`dockerd` (the daemon):**

- Receives API requests from clients
- Manages images, networks, volumes, build cache
- Delegates "run a container" operations down to containerd
- Handles logging drivers, plugins, authz
- One daemon per host

**`containerd`:**

- The heavy lifter — pulls images, manages snapshots, starts/stops containers
- Originally part of Docker; now a standalone **CNCF graduated** project
- Used by Kubernetes directly via the **Container Runtime Interface (CRI)**
- Other tools (Podman, nerdctl) also sit on top of containerd

**`containerd-shim`:**

- A small process that "parents" each container so containerd itself can restart without killing containers
- One shim per container

**`runc`:**

- The OCI reference implementation — takes an OCI bundle and calls the Linux kernel syscalls
  (`clone`, `unshare`, `pivot_root`, `setns`) to spawn the isolated process
- Extremely small and focused; alternatives exist (`crun` in C, `kata-runtime` for VM isolation)

> **Why so many layers?** Separation of concerns. Kubernetes replaced Docker with containerd
> directly in 2022 precisely because it only needed the lifecycle layer, not the full Docker daemon.

---

## Images, Containers, Registries

**Three nouns you'll use constantly:**

| | What it is | Where it lives |
|---|---|---|
| **Image** | Read-only template — files + metadata, organized in layers | Local disk or a registry |
| **Container** | Running instance of an image — image + a thin writable layer | Host where dockerd runs |
| **Registry** | Service that stores and serves images over HTTP | Docker Hub, GCR, ECR, ACR, Harbor |

```
┌────────────┐   docker run   ┌────────────┐
│   Image    │ ─────────────► │ Container  │
│ (template) │                │ (process)  │
└─────┬──────┘                └────────────┘
      │ docker pull / push
      ▼
┌────────────┐
│  Registry  │
└────────────┘
```

---

## Image Layers and the Union Filesystem

An image is not a single blob — it is a **stack of read-only layers**, each produced by an
instruction in a Dockerfile.

```
Layer 5:  app source code      ◄── your code
Layer 4:  pip install requirements
Layer 3:  apt-get install curl
Layer 2:  python:3.11 runtime
Layer 1:  debian base filesystem
```

A **union filesystem** (OverlayFS on modern Linux) merges the layers at runtime so the
container sees a single combined view.

**Benefits:**

- **Sharing** — two images that share a base layer use the same bytes on disk
- **Cache** — rebuilding only re-runs layers whose inputs changed
- **Transfer** — pushing/pulling only moves layers the registry doesn't already have

---

## Copy-on-Write (CoW)

When you `docker run` an image:

1. The engine creates a thin **writable layer** on top of the image's read-only layers
2. Reads walk down the stack to find the first copy of a file
3. The first **write** to a file copies it up into the writable layer (copy-on-write)
4. The image layers themselves are **never modified**

```
┌──────────────────────────┐
│ Writable container layer │ ◄── writes land here
├──────────────────────────┤
│       Image layers       │ ◄── read-only, shared
│  (possibly 5–15 deep)    │
└──────────────────────────┘
```

**Consequences:**

- Starting 100 containers from the same image costs ~100 thin writable layers, not 100 full copies
- Data written into the container layer disappears when the container is removed — for
  persistent data you need **volumes** (Session 7)
- Writes to large files can be surprisingly slow (first modification copies the whole file up)

---

## Storage Drivers (Graph Drivers)

The daemon-level component that implements the union filesystem.

| Driver | Notes |
|---|---|
| **overlay2** | Default on modern Linux; backed by OverlayFS; best general-purpose choice |
| **btrfs** | Uses btrfs subvolumes/snapshots; requires btrfs filesystem |
| **zfs** | Uses ZFS datasets; excellent snapshots; requires ZFS |
| **devicemapper** | Legacy; used on older RHEL/CentOS; being phased out |
| **vfs** | No CoW — each layer is a full copy; used for testing only |

Check yours:

```bash
docker info | grep -A 2 "Storage Driver"
```

---

## The Docker Object Model

Everything the daemon manages is one of these:

- **Images** — `docker image ls`, `docker pull`, `docker build`
- **Containers** — `docker ps`, `docker run`, `docker stop`
- **Volumes** — `docker volume ls`, `docker volume create`
- **Networks** — `docker network ls`, `docker network create`
- **Plugins** — volume drivers, network drivers, authorization
- **System** — `docker system df`, `docker system prune`

The CLI uses a **noun-verb-options** form:

```
docker <noun> <verb> [options]

docker container run -d --name web -p 8080:80 nginx:1.25
docker image build -t myapp:1.0 .
docker volume create data
docker network create --driver bridge app-net
```

Older `docker run`, `docker build` forms still work, but the `<noun> <verb>` form is clearer
and matches how tabs complete in `docker --help`.

---

## Docker on Linux vs macOS vs Windows

The daemon and containers are **Linux-native** — they depend on Linux kernel features
(namespaces, cgroups, OverlayFS).

- **Linux** — daemon runs directly on the host kernel
- **macOS** — Docker Desktop runs a tiny Linux VM (xhyve/HyperKit/virtualization framework);
  dockerd lives inside that VM
- **Windows** — Docker Desktop uses **WSL 2** (Windows Subsystem for Linux); containers run
  inside the WSL Linux kernel. Native Windows containers exist but are a separate path.

**Implications:**

- On macOS/Windows, `docker run -v ./data:/data` involves a VM boundary crossing — file I/O
  is slower than on Linux
- `--network host` works differently because "host" is the VM, not your laptop
- On a Linux server you have one fewer layer to reason about

---

## Docker Inc. Packages vs Distribution Packages

Linux distributions ship their own `docker` packages — these often lag Docker Inc's releases
by months and have sometimes carried patches that introduced security issues.

**Recommended installation path on Linux:**

```bash
curl -fsSL https://get.docker.com | sh
# then
sudo usermod -aG docker $USER
```

This pulls directly from Docker Inc's apt/yum repos and keeps you current.

---

## Key Takeaways

- Docker is a **client/daemon architecture** — `docker` is just a CLI; `dockerd` does the work
- Under the hood: **dockerd → containerd → containerd-shim → runc → container**
- Kubernetes talks to **containerd directly** via CRI — it does not need dockerd
- Images are **layered**; containers add a **copy-on-write** writable layer on top
- **OverlayFS** is the default storage driver on modern Linux
- Containers are Linux-native — macOS/Windows run a hidden Linux VM to host the daemon

---

## Review Questions

### Beginner

1. What is the relationship between `docker` (the CLI) and `dockerd` (the daemon)?
2. Name the four processes in the chain from `docker run` to a running container.
3. What is a container image made of?
4. Why does starting 100 containers from the same image not use 100× the disk space?
5. Why does Docker Desktop on macOS need a Linux VM?

### Intermediate

1. Kubernetes removed `dockershim` in v1.24 and now talks to containerd directly. What part
   of the Docker architecture did Kubernetes actually need, and what was it doing without?
2. You write a 1 GB file inside a running container, then delete the container. Where did
   the file live while the container was running, and where did it go when the container was
   removed? Why?
3. A coworker says "adding someone to the `docker` group is fine, it's not root." How would
   you respond, and what does the command `docker run -v /:/host alpine` demonstrate?
