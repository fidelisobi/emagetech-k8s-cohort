# Lab 02: Docker Architecture — Daemon, containerd, runc

## Overview

You'll look at the Docker architecture from the outside (API calls) and from the inside
(the process tree: `dockerd → containerd → containerd-shim → runc → your process`). You'll
also explore image layers and the copy-on-write filesystem.

**Estimated time:** 40 minutes

**Prerequisites:**

- Docker installed and working (Lab 01)
- Linux host **or** WSL 2 for the deeper process inspection
- `jq` installed (`brew install jq` / `apt install jq`)

> **macOS / Windows users**: the daemon lives inside the Docker Desktop VM. Sections that
> need `/proc` / `systemctl` should be run in the VM. See the "Desktop-only" notes where
> applicable.

---

## Part 1: The Client/Daemon Split

### 1.1 Version both sides

```bash
docker version
```

Notice the **Client** and **Server** sections — two binaries, two versions, two build dates.
The client just translates your commands into API calls.

### 1.2 Daemon-wide info

```bash
docker info
```

Note these fields:

- **Server Version** — dockerd version
- **Storage Driver** — usually `overlay2`
- **Cgroup Driver** — `systemd` or `cgroupfs`
- **Cgroup Version** — `1` or `2`
- **Default Runtime** — `runc`
- **Containerd Version** — the container lifecycle manager
- **Runc Version** — the OCI runtime

### 1.3 Talk to the API directly

On Linux:

```bash
# The daemon listens on a Unix socket
ls -l /var/run/docker.sock
sudo curl --unix-socket /var/run/docker.sock http://localhost/v1.43/info | jq '.ServerVersion'
sudo curl --unix-socket /var/run/docker.sock http://localhost/v1.43/containers/json | jq '.[].Names'
```

On macOS (Docker Desktop) the socket is still available:

```bash
curl --unix-socket ~/.docker/run/docker.sock http://localhost/v1.43/info | jq '.ServerVersion'
```

> **Question:** What does it mean that anyone in the `docker` group can read/write this
> socket? (Hint: what's on the other end of the socket?)

---

## Part 2: The Process Tree (Linux / WSL / Docker Desktop VM)

### 2.1 Start a long-running container

```bash
docker container run -d --name inspectme alpine sleep 1d
```

### 2.2 Look at the host process tree

```bash
pstree -asp $(pgrep dockerd | head -1)
```

You should see, roughly:

```
systemd
 └── dockerd
      └── containerd
           └── containerd-shim-runc-v2
                └── sleep 1d
```

**Each layer:**

| Process | Role |
|---|---|
| `dockerd` | The Docker daemon — speaks the REST API, owns images/volumes/networks |
| `containerd` | Lifecycle manager — starts/stops containers, manages snapshots |
| `containerd-shim-runc-v2` | Per-container supervisor — keeps the container alive if containerd restarts |
| `sleep 1d` | **Your container's PID 1** |

### 2.3 Find PIDs by hand

```bash
# The container's PID on the host
PID=$(docker container inspect -f '{{.State.Pid}}' inspectme)
echo "host PID: $PID"

# The parent is the shim
cat /proc/$PID/status | grep -E 'PPid|Name'
SHIM=$(awk '/PPid/ {print $2}' /proc/$PID/status)
cat /proc/$SHIM/status | grep -E 'PPid|Name'
```

Walk up the chain. The shim's parent will be containerd, whose parent is dockerd.

---

## Part 3: Kubernetes Skips the Daemon

Kubernetes v1.24+ talks to **containerd directly** via CRI. Docker Desktop includes both
— `containerd` is running under the hood. Verify:

```bash
# On a Linux host
sudo systemctl status containerd
```

```bash
# containerd's namespaces (not Linux namespaces — containerd's API-level grouping)
docker container run -d --name second alpine sleep 1d
sudo ctr namespace ls                     # ctr is containerd's CLI
sudo ctr -n moby container ls             # Docker uses the 'moby' namespace
```

> **Question:** Why did Kubernetes remove dockershim? What did it gain by talking to
> containerd directly?

---

## Part 4: Images as Stacks of Layers

### 4.1 Pull a rich image

```bash
docker image pull python:3.11-slim
```

### 4.2 Inspect history

```bash
docker image history python:3.11-slim
docker image history --no-trunc python:3.11-slim | head -20
```

Each row is one layer. The `CREATED BY` column is the Dockerfile instruction that produced
it.

### 4.3 See the layers on disk (Linux)

```bash
sudo ls /var/lib/docker/overlay2 | head
sudo du -sh /var/lib/docker/overlay2/*/ 2>/dev/null | sort -h | tail -5
```

Each directory is a layer. The total is smaller than the sum of images because **shared
base layers are stored once**.

### 4.4 Prove layers are shared

```bash
docker image pull python:3.11           # full image
docker image ls python

# Size reported for each = total, but they share lower layers on disk
docker system df                         # 'Images' reclaimable shows the overlap
```

---

## Part 5: Copy-on-Write in Action

### 5.1 Start two containers from the same image

```bash
docker container run -d --name c1 alpine sh -c 'sleep 1d'
docker container run -d --name c2 alpine sh -c 'sleep 1d'
```

### 5.2 Write into one — read from the other

```bash
docker container exec c1 sh -c 'echo "hello from c1" > /shared.txt; ls -l /shared.txt'

docker container exec c2 ls -l /shared.txt
# ls: /shared.txt: No such file or directory
```

Each container has its **own writable layer**. Writes in c1 don't show up in c2 — the image
layers are read-only and unchanged.

### 5.3 Peek at the writable layer (Linux only)

```bash
# Find c1's upper dir
docker container inspect c1 -f '{{.GraphDriver.Data.UpperDir}}'
sudo ls -l "$(docker container inspect c1 -f '{{.GraphDriver.Data.UpperDir}}')"
```

You'll see `shared.txt` sitting there. This is the copy-on-write tip of the overlay.

### 5.4 Remove the container — watch the write vanish

```bash
docker container rm -f c1
# the upper dir is deleted with the container
```

---

## Part 6: OCI Image Format Under the Hood

### 6.1 Export the image as a tar

```bash
docker image save alpine:3.19 -o alpine.tar
mkdir /tmp/alpine-image && tar -xf alpine.tar -C /tmp/alpine-image
ls /tmp/alpine-image
```

### 6.2 Walk the manifest

```bash
cat /tmp/alpine-image/manifest.json | jq
# Each layer referenced is a tar inside the export
```

### 6.3 Peek at a layer

```bash
LAYER=$(cat /tmp/alpine-image/manifest.json | jq -r '.[0].Layers[0]')
tar -tf /tmp/alpine-image/$LAYER | head
```

You're looking at a plain tar of filesystem paths. That's all a layer is.

### 6.4 Clean up

```bash
rm -rf /tmp/alpine-image alpine.tar
```

---

## Part 7: Storage Driver Quick Check

```bash
docker info | grep -E 'Storage Driver|Backing Filesystem'
```

Almost every modern Linux host uses **overlay2** over ext4 or xfs. If you see something
else (devicemapper, vfs), you're on an unusual or very old setup.

---

## Clean Up

```bash
docker container rm -f inspectme second c2 2>/dev/null
docker system prune -f
```

---

## Summary

After completing this lab you should be able to:

- Explain the **docker CLI → dockerd → containerd → shim → runc** chain and why each exists
- Talk directly to the Docker REST API over its Unix socket
- Walk a container's **host-side process tree** with `pstree` and `/proc`
- Tell the difference between Docker's view of an image (layers, digests) and the **OCI
  image format** on disk (manifest + tar layers)
- Observe **copy-on-write** by writing in one container and reading from another
- Find a container's **writable overlay upperdir** on the host

---

## Stretch Goals

1. Install `ctr` usage skills: `sudo ctr -n moby image ls` and `sudo ctr -n moby task ls`.
   Compare their output to `docker image ls` / `docker ps`.
2. Write a minimal shell script that uses only `curl` + the Unix socket to list running
   containers — no `docker` CLI.
3. Change the default storage driver to `fuse-overlayfs` in a disposable VM and re-run
   Part 5 — what changes?
