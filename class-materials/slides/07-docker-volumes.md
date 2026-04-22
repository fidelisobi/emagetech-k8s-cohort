# Session 7 — Docker Volumes

---

## The Ephemeral Filesystem Problem

A container's writable layer disappears when the container is removed. Anything written
there — database files, uploaded media, logs — is **gone**.

```bash
docker container run --rm postgres:16       # fresh data on every run
docker container stop postgres && docker container rm postgres   # data: gone
```

For anything you want to keep, you need storage **outside** the container's writable layer.

---

## Three Ways to Mount Data

| Type | Managed by Docker? | Host path you pick? | Best for |
|---|---|---|---|
| **Named volumes** | Yes | No — Docker stores under `/var/lib/docker/volumes/` | Databases, app data — the default choice |
| **Bind mounts** | No | Yes | Dev loops, host config files |
| **tmpfs** | Yes | N/A — RAM only | Secrets, scratch space that must not persist |

All three are mounted into the container's filesystem at a path you choose.

---

## Named Volumes

Docker creates, names, and manages the volume. The host location is an implementation
detail — you reference the volume by name.

```bash
# Create
docker volume create pg-data

# Use
docker container run -d \
  --name pg \
  -v pg-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:16

# Inspect
docker volume ls
docker volume inspect pg-data
docker volume rm pg-data        # must not be in use
```

**Why prefer named volumes:**

- Docker manages lifecycle (creation, removal, driver)
- Portable across Linux/macOS/Windows (bind mounts cross VM boundaries on Desktop)
- Safely shareable between containers
- Can use volume drivers for cloud/NFS storage

---

## The Modern `--mount` Syntax

`-v` is terse and historic; `--mount` is verbose, explicit, and preferred for scripts and
Compose files.

```bash
# Named volume
docker container run -d \
  --mount type=volume,source=pg-data,target=/var/lib/postgresql/data \
  postgres:16

# Bind mount
docker container run -d \
  --mount type=bind,source="$(pwd)"/src,target=/app,readonly \
  node:20 npm run dev

# tmpfs
docker container run -d \
  --mount type=tmpfs,target=/tmp,tmpfs-size=64m \
  alpine
```

The fields are key=value, comma-separated. Typos fail loudly — unlike `-v`, which silently
creates an anonymous volume if you misspell.

---

## Bind Mounts

A bind mount maps a **host directory** into the container.

```bash
docker container run -d \
  --name dev \
  -v "$(pwd)":/app \
  -w /app \
  node:20 npm run dev
```

**Pros:**

- Zero-copy dev loop — edit on host, container sees changes immediately
- Host owns the data; survives container removal; easy to inspect with regular tools

**Cons:**

- Couples the container to a specific host path — not portable
- Permissions are raw — UID/GID on host must match what the container expects
- On Docker Desktop (macOS/Windows), file I/O crosses the VM boundary and is slow; tools
  like VirtioFS and gRPC-FUSE help but don't beat native Linux
- **Security hazard** — `-v /:/host` gives the container your entire host

**Use bind mounts for:** developer workflows and injecting config files. Avoid them in
production manifests.

---

## Anonymous Volumes

Omit the source and Docker creates a volume with a random name:

```bash
docker container run -d -v /var/lib/mysql mysql:8
```

These silently pile up. Prefer named volumes or `--rm` for ephemeral data. Clean up:

```bash
docker volume ls -f dangling=true
docker volume prune
```

---

## Read-Only Mounts

Mount data the container only needs to read:

```bash
docker container run -d \
  --mount type=volume,source=site-content,target=/usr/share/nginx/html,readonly \
  nginx
```

Or with `-v`:

```bash
docker container run -d -v site-content:/usr/share/nginx/html:ro nginx
```

Combined with `--read-only` (the **entire container filesystem** is RO) you get a very
hard-to-compromise runtime — useful for hardened deployments.

---

## Sharing Data Between Containers

Two containers can mount the same volume. Useful for sidecars, backups, and producer/
consumer pipelines.

```bash
docker volume create shared

docker container run -d --name writer \
  --mount type=volume,source=shared,target=/data \
  alpine sh -c 'while true; do date >> /data/log; sleep 5; done'

docker container run --rm \
  --mount type=volume,source=shared,target=/data,readonly \
  alpine tail -f /data/log
```

If two writers hit the same files, you own the concurrency story — Docker doesn't arbitrate.

---

## Volumes in Dockerfiles: `VOLUME`

```dockerfile
FROM postgres:16
VOLUME ["/var/lib/postgresql/data"]
```

When a container starts from this image **and no mount is provided for that path**, Docker
creates an **anonymous volume** automatically.

**Tradeoffs:**

- Protects users from accidentally losing data in the writable layer
- Creates volume clutter if users forget to mount a named volume
- Any file you `COPY` into a `VOLUME` path **before** declaring it is lost — declaration
  order matters

Most modern images (including official Postgres/MySQL) document the data path and let
**users** pick how to mount.

---

## Backup, Restore, Migrate

A volume is just a directory the Docker daemon owns. Use another container to read/write
it over tar:

```bash
# Backup to a tarball
docker run --rm \
  -v pg-data:/data \
  -v "$(pwd)":/backup \
  alpine tar -czf /backup/pg-data.tgz -C /data .

# Restore into a new volume
docker volume create pg-data-restore
docker run --rm \
  -v pg-data-restore:/data \
  -v "$(pwd)":/backup \
  alpine tar -xzf /backup/pg-data.tgz -C /data
```

The pattern is "attach a helper container to the volume + a host bind mount, shuffle data
through tar." It's general-purpose — works for any volume driver.

---

## Volume Drivers and Remote Storage

The default driver is `local` (data lives on the host). Plugins let volumes live on remote
storage:

- `local` + NFS options — `--driver local --opt type=nfs --opt o=addr=10.0.0.1,…`
- `nvidia` — GPU-aware volumes (CUDA cache)
- Cloud-provider drivers — EBS, GCE PD, Azure Disk (usually through CSI on Kubernetes, not
  raw Docker)

```bash
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.corp.local,rw \
  --opt device=:/exports/shared \
  nfs-vol
```

Mount it just like a named volume. The daemon handles the mount/unmount.

---

## tmpfs — When You Must Not Persist

```bash
docker container run -d \
  --tmpfs /tmp:rw,size=64m,noexec,nosuid \
  alpine sleep 1d
```

- Lives in RAM; vanishes when the container stops
- Good for: decrypted secrets, caches that must not leak, session scratch
- Counts against the container's memory budget

---

## Stateful Container Patterns

| Pattern | How |
|---|---|
| **Single container + named volume** | Simplest DB; easy backups |
| **Sidecar writes, main reads** | Shared volume for logs, media, config |
| **External storage** | Volume backed by NFS/EFS/NetApp so the container is stateless |
| **Move state out of containers** | DB as a managed service (Cloud SQL, RDS, Azure SQL); container stays ephemeral |

In production, **managed databases** beat self-hosted in a container nearly every time —
less to back up, patch, or upgrade. Use volumes for caches, uploads, and services where
"losing data" is acceptable or backups are rock solid.

---

## In Kubernetes, This Is a Whole Session

Kubernetes replaces these concepts with:

- **Volumes** — scoped to a Pod (the K8s equivalent of "a running container")
- **PersistentVolumes / PersistentVolumeClaims** — decouple storage from Pods
- **StorageClasses** — dynamic provisioning of cloud disks (EBS, GCE PD, Azure Disk)
- **CSI drivers** — the plugin model for volume drivers

Same mental model (a mount into a container at a target path), bigger machinery around it.
Deep dive in **Session 20**.

---

## Common Pitfalls

- **Typing `-v myvol:/data` with a typo** → anonymous volume; original data "missing"
- **Bind-mounting over an existing image directory** → image contents hidden, not merged
- **Using bind mounts in production** → breaks portability; couples to host layout
- **Not backing up volumes** → `docker volume prune` is unforgiving
- **Sharing a volume between two writers with no locking** → data corruption
- **Granting a container access to the Docker socket via bind mount** → effective host root

---

## Key Takeaways

- Writes to the container filesystem are **ephemeral** — you need a volume to persist them
- **Named volumes** are the default choice; bind mounts are a dev tool; tmpfs is RAM-only
- Prefer `--mount` syntax — clearer, typo-proof, matches Compose
- Back up volumes by mounting them into a helper container + tar
- Volume drivers let volumes live on NFS or cloud storage
- In Kubernetes, the same ideas become **PVCs + StorageClasses + CSI**

---

## Review Questions

### Beginner

1. What happens to data written inside a container when the container is removed?
2. When would you use a named volume vs a bind mount vs tmpfs?
3. Why might two copies of the same app on the same host both silently create "anonymous"
   volumes?
4. How do you mount a volume as read-only?
5. What command would you use to list volumes that nothing is using?

### Intermediate

1. You're migrating a Postgres container from one host to another. Describe, end to end,
   how you'd move the data without downtime longer than a restart.
2. A developer bind-mounts `~/.ssh` into a container to test a Git clone. What risks does
   this create, and what's the BuildKit-native alternative?
3. Your containerised app writes user uploads to `/app/uploads`. You're about to add a
   second replica behind a load balancer. What will go wrong if you use a default named
   volume, and what are two ways to fix it?
