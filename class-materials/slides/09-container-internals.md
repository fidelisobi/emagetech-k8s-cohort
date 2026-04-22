# Session 9 — Container Internals

---

## "A Container Is Just a Process"

Under the hood, there is no "container object" in the Linux kernel. A container is an
ordinary Linux process that the kernel has isolated with a particular combination of:

1. **Namespaces** — what the process can **see**
2. **Control groups (cgroups)** — what the process can **use**
3. **Capabilities** — what privileged operations it can **do**
4. **Seccomp / AppArmor / SELinux** — which syscalls / files it can call / access
5. **A root filesystem** — usually an overlay built from image layers

Remove any of these and you have a regular process. Add all of them and you have a container.

```bash
# On the host, find the PID of a containerised process
docker container inspect -f '{{.State.Pid}}' web
# Look at its namespaces
ls -l /proc/<PID>/ns/
```

---

## Linux Namespaces — What the Process Can See

Each namespace isolates one global kernel resource. The kernel provides seven used by
containers:

| Namespace | Isolates | Effect |
|---|---|---|
| **PID** | Process IDs | Container sees its own PID 1; can't see host processes |
| **NET** | Network stack | Own interfaces, routes, iptables, ports |
| **MNT** | Filesystem mounts | Own view of the filesystem tree |
| **UTS** | Hostname, domain name | Container can set its own hostname |
| **IPC** | SysV IPC, POSIX msg queues | Isolated shared memory / semaphores |
| **USER** | UID/GID mapping | Root inside → unprivileged outside (user namespaces) |
| **CGROUP** | View of cgroup hierarchy | Container sees its own cgroup tree |

**Hands-on: see the namespaces of a container:**

```bash
docker run -d --name demo alpine sleep 1d
PID=$(docker inspect -f '{{.State.Pid}}' demo)
sudo ls -l /proc/$PID/ns/
# net -> 'net:[4026532123]'
# pid -> 'pid:[4026532124]'
# ...
```

Each `[<inode>]` identifies a specific namespace. Two processes with the **same** inode
share that namespace.

**Enter a container's namespaces with `nsenter`:**

```bash
sudo nsenter -t $PID -a         # -a = all namespaces
# Now your shell is inside the container's world
```

Docker's `docker exec` is a friendlier wrapper for exactly this.

---

## The PID Namespace — "Hello, PID 1"

Inside a container, the first process is PID 1. On the host, it has some other PID.

```bash
docker run -d --name pid alpine sleep 1d
docker exec pid ps              # sees only itself as PID 1

HPID=$(docker inspect -f '{{.State.Pid}}' pid)
echo "on the host, it's PID $HPID"
```

**Why it matters:** PID 1 in Linux has special responsibilities — reaping orphaned child
processes and handling signals. If your app was not written to be PID 1 (most aren't), a
small init like `tini` (`docker run --init`) can fix zombie reaping without any code changes.

---

## The Mount Namespace and Overlay Filesystem

A container sees its own mount tree rooted at the overlay that the storage driver built
from the image's layers.

```bash
docker run -d --name fs alpine sleep 1d
PID=$(docker inspect -f '{{.State.Pid}}' fs)
sudo cat /proc/$PID/mountinfo | head -5
```

The `overlay` mount is the union of image layers (lowerdir) + the writable layer (upperdir).
Writes go to upperdir; reads fall through.

---

## The Network Namespace

Each container has its own:

- Interfaces (`eth0` inside is one end of a `veth` pair on the host)
- Routing table
- iptables rules
- Port namespace — "port 80" inside ≠ "port 80" on the host

```bash
docker run -d --name net nginx
docker exec net ip addr
docker exec net ip route
```

On the host, there's a matching `veth…@if<N>` that joins the container's netns to the
bridge:

```bash
ip link | grep veth
bridge link
```

---

## Control Groups (cgroups)

Namespaces answer "what can I see?" Cgroups answer "what can I use?"

A cgroup is a kernel-level resource accounting and limiting mechanism. The kernel places a
process into cgroups for CPU, memory, IO, PIDs, etc. — and enforces limits.

```bash
# Linux shows the controllers enabled on cgroup v2
cat /proc/self/cgroup
ls /sys/fs/cgroup
```

### cgroups v1 vs v2

| | cgroups v1 | cgroups v2 |
|---|---|---|
| Hierarchies | Many (one per controller) | **Single unified hierarchy** |
| API | Complex, per-controller files | Cleaner, uniform files |
| Status | Legacy | **Default on modern distros** (Ubuntu 22.04+, Fedora 31+) |
| Docker support | Full | Full on 20.10+ |

### The main controllers

| Controller | Limits |
|---|---|
| `cpu` | CPU time (shares, quotas) |
| `memory` | RAM + swap usage; OOM-kills on exceed |
| `io` | Disk I/O weight and throughput |
| `pids` | Maximum number of processes |
| `devices` | Device file access |
| `cpuset` | Pinning to specific CPUs / NUMA nodes |

### Docker flags → cgroups

```bash
docker run --memory=512m           # memory.max
docker run --cpus=1.5              # cpu.max
docker run --pids-limit=200        # pids.max
docker run --cpuset-cpus=0-3       # cpuset.cpus
docker run --blkio-weight=500      # io.weight
```

### Inspect a container's cgroup live

```bash
ID=$(docker run -d --memory=256m alpine sleep 1d)
docker inspect -f '{{.Id}}' $ID
# Find the cgroup (cgroupsv2)
find /sys/fs/cgroup -name "*$ID*"
cat /sys/fs/cgroup/system.slice/docker-$ID.scope/memory.max
cat /sys/fs/cgroup/system.slice/docker-$ID.scope/memory.current
```

Kubernetes `resources.requests/limits` ultimately become cgroup settings on the node — same
mechanism.

---

## Capabilities

Linux has split the traditional "root vs not root" binary into ~40 **capabilities** —
fine-grained privileges the kernel checks for each syscall.

Examples:

| Capability | Grants |
|---|---|
| `CAP_NET_BIND_SERVICE` | Bind to ports < 1024 |
| `CAP_NET_ADMIN` | Configure networks, routing, iptables |
| `CAP_SYS_ADMIN` | A grab-bag of powerful operations |
| `CAP_CHOWN` | Change file owner |
| `CAP_KILL` | Send signals to any process |

By default Docker containers get a **minimal set** of capabilities — much smaller than
actual root. Add or drop explicitly:

```bash
docker run --cap-add=NET_ADMIN --cap-drop=CHOWN alpine

# Best practice: drop everything, add only what you need
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx
```

`--privileged` is the nuclear option — grants **all** capabilities, disables seccomp, and
gives device access. Treat like `sudo rm -rf /`: rarely appropriate.

---

## Seccomp — Syscall Filtering

A **seccomp profile** is a syscall allowlist enforced by the kernel. Docker ships a
[default profile](https://docs.docker.com/engine/security/seccomp/) that blocks ~50
rarely-used / dangerous syscalls (e.g., `mount`, `reboot`, `kexec_load`).

```bash
# Run with the default seccomp profile (this is the default)
docker run alpine

# Disable seccomp — don't do this casually
docker run --security-opt seccomp=unconfined alpine

# Use a custom profile
docker run --security-opt seccomp=./my-profile.json alpine
```

---

## AppArmor / SELinux — Mandatory Access Control

AppArmor (Ubuntu/Debian) and SELinux (RHEL/Fedora) are kernel modules that apply
**per-process** access policies — what files, capabilities, and operations a confined
process can use.

Docker installs a default AppArmor profile (`docker-default`) on Ubuntu/Debian hosts.
On RHEL, SELinux enforces similar boundaries via the `container_t` type.

You rarely need to touch these unless you're hardening for regulated environments — but
knowing they're on helps when troubleshooting "permission denied" inside a privileged
container.

---

## User Namespaces — Root Inside, Not Root Outside

By default, root in a container **is** root on the host kernel (with most capabilities
stripped). User namespaces remap UIDs so that UID 0 inside the container is, say, UID
100000 on the host.

```bash
# dockerd remapping — set in /etc/docker/daemon.json
{
  "userns-remap": "default"
}
```

Tradeoffs:

- Big security win — an escape lands you as an unprivileged host user
- Breaks some workflows: bind-mounted files need matching host UIDs; some images assume
  real UID 0
- Podman does this by default via rootless containers

---

## OCI Runtimes: runc and Friends

**runc** is the reference OCI runtime — given a filesystem bundle + a JSON config, it
invokes the syscalls that create a container and `exec`s the target process.

Alternatives:

- **crun** — C rewrite of runc; faster startup, smaller
- **kata-runtime** — spins up a real lightweight VM per container; strong isolation at
  container speeds
- **gVisor (runsc)** — Google's user-space kernel; intercepts syscalls for hardened
  sandboxing
- **youki** — Rust implementation

Switch runtimes in `daemon.json` → `runtimes`, then `docker run --runtime=…`.

---

## Putting It Together: What `docker run` Actually Does

When you type `docker run -d --name web nginx`:

1. **docker CLI** sends a `POST /containers/create` + `POST /containers/{id}/start` to **dockerd**
2. **dockerd** pulls layers if missing; assembles a root filesystem with **OverlayFS**
3. dockerd asks **containerd** to create a container
4. containerd writes an **OCI bundle** (rootfs + config.json) and starts a
   **containerd-shim** to supervise it
5. The shim invokes **runc**, which calls `clone()` with the right namespace flags,
   configures cgroups, drops capabilities, applies seccomp, pivots root, and execs `nginx`
6. The shim keeps the container's stdio; `dockerd` streams logs to the configured driver

All of that, to run a process.

---

## Key Takeaways

- A container = **namespaces + cgroups + capabilities + seccomp/LSM + rootfs**
- **Namespaces** control **what you see**; **cgroups** control **what you use**
- PID 1 inside is the container's entrypoint — think about signal handling and zombie reaping
- **cgroups v2** is the modern unified hierarchy; Docker maps `--memory`/`--cpus` onto it
- Default capabilities are already reduced; **drop ALL, add back explicitly** for hardening
- **runc** is the reference runtime; **kata**/**gVisor** trade speed for stronger isolation
- All of this is boring, well-documented Linux — `nsenter`, `lsns`, `/proc/<pid>/*` let you
  see the machinery directly

---

## Review Questions

### Beginner

1. Name four kernel namespaces a container uses and what each isolates.
2. What's the difference between namespaces and cgroups?
3. Why is it important that your container's main process is PID 1?
4. What does `--privileged` do, and why is it usually a bad idea?
5. Which OCI runtime does Docker use by default, and what does it actually do?

### Intermediate

1. Your container hits `OOMKilled` but you didn't set `--memory`. What are the likely causes,
   and where on the host would you look to confirm?
2. A vendor's container runs fine with `--privileged` but fails without it. How would you
   work out which capability or seccomp rule it actually needs, and then ship a least-
   privilege run command?
3. Explain end-to-end, at the syscall level, what happens between typing `docker run` and
   `ps` showing your process. Include dockerd, containerd, shim, and runc.
