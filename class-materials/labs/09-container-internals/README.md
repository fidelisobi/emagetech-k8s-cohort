# Lab 09: Container Internals — Namespaces, cgroups, Capabilities

## Overview

You'll prove that a container is "just a process" by looking at its Linux namespaces and
cgroups, entering its namespaces with `nsenter`, enforcing resource limits and watching
them work, and dropping capabilities to build a least-privilege run.

**Estimated time:** 60 minutes

**Prerequisites:**

- A **Linux** host or WSL 2. (Docker Desktop VM will work if you can get a shell into it —
  sections that use `nsenter` / `lsns` / `/sys/fs/cgroup` require Linux tools.)
- `sudo` on the Linux host
- Docker installed and working
- `jq`, `stress-ng` (`apt install stress-ng` / `brew install stress-ng`)

---

## Part 1: "A Container Is a Process"

### 1.1 Start a long-running container

```bash
docker container run -d --name internals alpine sleep 1d
```

### 1.2 Find its host PID

```bash
PID=$(docker container inspect -f '{{.State.Pid}}' internals)
echo "Host PID: $PID"
ps -p $PID -o pid,ppid,comm,args
```

It's a normal Linux process. Its parent is the `containerd-shim-runc-v2`.

### 1.3 From inside, it's PID 1

```bash
docker container exec internals ps
# PID  USER     TIME  COMMAND
#  1   root     0:00  sleep 1d
```

---

## Part 2: Namespaces — What the Process Can See

### 2.1 List the namespaces

```bash
sudo ls -l /proc/$PID/ns/
```

You'll see symlinks like `net -> net:[4026532123]` — the bracketed number is the namespace
inode. Two processes sharing a namespace share the inode.

### 2.2 Show the host's own namespaces for comparison

```bash
sudo ls -l /proc/1/ns/                         # systemd / init
```

Compare the inode numbers — container namespaces are different from the host's.

### 2.3 `lsns` tells you which namespaces exist and which PIDs are in them

```bash
sudo lsns | head
sudo lsns | grep $PID
```

---

## Part 3: Enter a Container's Namespaces

### 3.1 `nsenter` joins all namespaces of a target PID

```bash
sudo nsenter -t $PID -a
# now your shell is inside the container's network, mount, pid, uts, ipc namespaces
hostname            # container's hostname
ps aux              # only container processes
ip addr             # container's eth0
exit
```

`docker exec` is effectively a wrapper around this.

### 3.2 Join just one namespace — the network

```bash
sudo nsenter -t $PID -n ip addr
sudo nsenter -t $PID -n ss -tlnp
```

Useful for debugging without leaving the host.

---

## Part 4: PID Namespace & Zombie Reaping

### 4.1 Without `--init`

```bash
docker container run -d --name noinit alpine sh -c \
  'sh -c "sleep 5 &"; sleep 1d'

sleep 7
docker container exec noinit ps
# you may see a <defunct> / zombie — PID 1 didn't reap it
docker container rm -f noinit
```

### 4.2 With `--init`

```bash
docker container run -d --init --name withinit alpine sh -c \
  'sh -c "sleep 5 &"; sleep 1d'

sleep 7
docker container exec withinit ps
# no zombies — tini (PID 1) reaped them
docker container rm -f withinit
```

> **Question:** In Kubernetes, what's the equivalent of `--init` (hint: `shareProcessNamespace`
> + a sidecar or `securityContext`), and what do most folks do instead?

---

## Part 5: Control Groups (cgroups v2)

### 5.1 Find a container's cgroup

```bash
ID=$(docker container inspect -f '{{.Id}}' internals)
CGROUP=$(find /sys/fs/cgroup -name "docker-$ID.scope" 2>/dev/null | head -1)
echo "cgroup: $CGROUP"
ls "$CGROUP"
```

You'll see files like `memory.max`, `memory.current`, `cpu.max`, `pids.max`, `io.stat`.

### 5.2 Set and verify a memory limit

```bash
docker container rm -f capped 2>/dev/null
docker container run -d --name capped --memory=128m alpine sleep 1d

CAPID=$(docker container inspect -f '{{.Id}}' capped)
CGROUP=$(find /sys/fs/cgroup -name "docker-$CAPID.scope" 2>/dev/null | head -1)
cat $CGROUP/memory.max            # 134217728  (= 128 MiB)
cat $CGROUP/memory.current        # whatever it's using now
```

### 5.3 Enforce the limit

```bash
docker container rm -f capped
docker container run --rm --memory=128m alpine \
  sh -c 'dd if=/dev/zero of=/dev/shm/x bs=1M count=500 2>&1 | tail'
echo "Exit: $?"                  # 137 — OOMKill
```

### 5.4 Watch CPU throttling

```bash
docker container run -d --name hot --cpus=0.5 alpine sh -c 'while :; do :; done'
sleep 2
docker container stats --no-stream hot       # around 50% CPU
docker container rm -f hot
```

### 5.5 PIDs limit blocks fork bombs

```bash
docker container run -d --name bounded --pids-limit=20 alpine sleep 1d

for i in $(seq 1 30); do
  docker container exec bounded sh -c 'sleep 60 &' 2>&1 | grep -q "resource" && { echo "blocked at $i"; break; }
done

docker container rm -f bounded
```

---

## Part 6: Capabilities

### 6.1 The default set

```bash
docker container run --rm alpine sh -c 'apk add --quiet libcap 2>/dev/null; capsh --print' | head
```

Notice it is much smaller than `cap_sys_admin, cap_net_admin, cap_sys_ptrace, …` — Docker
drops most caps even for "root" in a container.

### 6.2 Drop everything, add back selectively

```bash
docker container run --rm \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  alpine sh -c 'apk add --quiet libcap 2>/dev/null; capsh --print | grep Current'
```

### 6.3 Watch a capability actually matter

```bash
# Without NET_RAW, ping fails
docker container run --rm --cap-drop=ALL alpine \
  sh -c 'apk add --quiet iputils 2>/dev/null; ping -c 1 -W 1 8.8.8.8' || echo "no raw socket"

# With NET_RAW, it works
docker container run --rm --cap-drop=ALL --cap-add=NET_RAW alpine \
  sh -c 'apk add --quiet iputils 2>/dev/null; ping -c 1 -W 1 8.8.8.8'
```

### 6.4 `--privileged` — the opposite

```bash
docker container run --rm --privileged alpine \
  sh -c 'apk add --quiet libcap 2>/dev/null; capsh --print | grep Current'
```

Lists **everything** — this is why you almost never want `--privileged`.

---

## Part 7: Seccomp

### 7.1 Default profile blocks some syscalls

```bash
# The default seccomp profile blocks reboot, mount, kexec, etc.
docker container run --rm alpine sh -c 'mount -t tmpfs none /mnt 2>&1; echo exit=$?'
# Will succeed because `mount` capability is dropped but seccomp allows the syscall
# (a real exploit would need syscall permission AND capability)

# Disable seccomp — not recommended, demonstrated for comparison
docker container run --rm --security-opt seccomp=unconfined alpine sh -c 'id'
```

### 7.2 `no-new-privileges`

Combined with `--cap-drop=ALL`, `--security-opt no-new-privileges` blocks suid-based
escalation:

```bash
docker container run --rm \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  alpine id
```

---

## Part 8: User Namespaces (Optional)

If userns is enabled in your daemon:

```bash
sudo cat /etc/docker/daemon.json 2>/dev/null | grep userns || echo "userns-remap not configured"
```

When configured (`"userns-remap": "default"` in `daemon.json`, then `systemctl restart docker`),
UID 0 inside a container is mapped to an unprivileged UID on the host — a container root
escape lands as an unprivileged host user.

```bash
docker container run --rm alpine id
# uid=0 (root) inside — but if userns is on, host /proc/<pid>/status shows a different Uid
```

---

## Part 9: Runtimes

### 9.1 Default runtime

```bash
docker info | grep -i runtime
```

You should see `Default Runtime: runc`.

### 9.2 Bonus — install `crun` and try it

```bash
# Debian/Ubuntu
sudo apt install crun

# Add a runtime entry to /etc/docker/daemon.json:
# { "runtimes": { "crun": { "path": "/usr/bin/crun" } } }
sudo systemctl restart docker

docker container run --rm --runtime=crun alpine echo "hello from crun"
docker container run --rm --runtime=runc alpine echo "hello from runc"
```

Same container image, different OCI runtime. Faster startup with crun. Pair this with
`docker info | grep Runtimes` to confirm both are registered.

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker system prune -f
```

---

## Summary

After completing this lab you should be able to:

- Find a container's host PID and confirm it's a normal Linux process
- List its **namespaces** (`/proc/<pid>/ns/`, `lsns`) and enter them (`nsenter`)
- Explain PID 1 and why `--init` (tini) fixes zombie reaping
- Inspect a container's **cgroup v2** files and see `--memory`/`--cpus`/`--pids-limit`
  enforced
- List a container's **capabilities** with `capsh` and demonstrate `--cap-drop=ALL`
- Use `--security-opt no-new-privileges` in combination with cap-drops for hardened runs
- Recognise when a runtime swap (crun, kata, gVisor) might be worth pursuing

---

## Stretch Goals

1. Use `strace -p $PID` to watch syscalls made by `sleep 1d` inside a container. How many
   syscalls per second? Why so few?
2. Run an nginx container with `--cap-drop=ALL`. Does it start? What goes wrong? What's the
   minimal `--cap-add` list?
3. Pick a workload that legitimately needs a kernel capability (e.g., `tcpdump` needs
   `NET_RAW` + `NET_ADMIN`) and write the least-privilege `docker run` command for it.
