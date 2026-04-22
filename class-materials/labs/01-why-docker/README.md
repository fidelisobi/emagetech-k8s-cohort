# Lab 01: Why Docker? — First Containers

## Overview

In this lab you will install Docker (if not already installed), run your first containers,
see why containers start so fast, and compare a container to a process on the host. No
application code is written — the goal is to build intuition.

**Estimated time:** 30 minutes

**Prerequisites:**

- A laptop running macOS, Windows, or Linux with admin privileges
- Internet access (for pulling images)

---

## Part 1: Install Docker

### 1.1 macOS / Windows

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/). Start it and wait
for the whale icon to stop animating.

### 1.2 Linux

Use the Docker-provided convenience script — most distros' own packages lag behind:

```bash
curl -fsSL https://get.docker.com | sh

# Run docker without sudo (log out / back in after this)
sudo usermod -aG docker $USER
```

### 1.3 Verify

```bash
docker version           # client + server versions
docker info              # daemon-wide config
```

You should see both a **Client** and a **Server** section. If the Server section is missing,
the daemon isn't reachable — check Docker Desktop is running (macOS/Windows) or
`systemctl status docker` (Linux).

---

## Part 2: Run Your First Container

### 2.1 `hello-world`

```bash
docker container run hello-world
```

Trace what happened from the output:

1. The client asked the daemon to run `hello-world`
2. Daemon didn't have it → pulled from Docker Hub
3. A container was created from the image
4. It printed its message and exited

```bash
# The container is still on disk, in 'Exited' state
docker container ls -a

# Remove it
docker container rm <NAME>
```

### 2.2 Busybox and Ubuntu

```bash
docker container run busybox echo "hi from busybox"
docker container run alpine uname -r           # kernel version inside the container
uname -r                                       # kernel version on the host
```

> **Question:** Why are the two `uname -r` outputs the same even though one ran "inside a
> container"?

### 2.3 An interactive shell

```bash
docker container run -it --rm ubuntu bash
# inside the container:
cat /etc/os-release
apt list --installed | head
exit
```

`-it` keeps STDIN open (`-i`) and allocates a TTY (`-t`). `--rm` removes the container
automatically when you exit.

---

## Part 3: Measure Start Time

### 3.1 Time a container start

```bash
time docker container run --rm alpine echo "go"
```

On a warm cache, this should be well under a second.

### 3.2 (Optional) Compare to a VM

If you have a VM tool handy (multipass, VirtualBox, Vagrant, Lima), compare how long a
minimal VM takes to boot:

```bash
# Example with multipass
time multipass launch --name throwaway --cpus 1 --memory 512M --disk 2G
multipass delete throwaway && multipass purge
```

> **Question:** What makes the container orders of magnitude faster?

---

## Part 4: Container vs Host Process

### 4.1 Start a long-running container

```bash
docker container run -d --name stayalive alpine sleep 1d
```

`-d` runs it in the background and prints the container ID.

### 4.2 See it from inside

```bash
docker container exec stayalive ps aux
```

You'll see only one or two processes.

### 4.3 See it from the host

On Linux:

```bash
ps -ef | grep sleep | grep -v grep
```

On macOS / Windows (Docker Desktop), the daemon and all container processes live inside
the Docker Desktop Linux VM. Use:

```bash
docker container inspect -f '{{.State.Pid}}' stayalive
```

> **Question:** Inside the container the `sleep` command is PID 1. On a Linux host it has
> some other PID — what's the significance of those two numbers being different?

### 4.4 Clean up

```bash
docker container rm -f stayalive
```

---

## Part 5: Pets vs Cattle — Replace, Don't Repair

### 5.1 Start three nginx instances

```bash
for i in 1 2 3; do
  docker container run -d --name web-$i -p 808$i:80 nginx:1.25
done

docker container ls
```

### 5.2 "Break" one of them

```bash
docker container kill web-2
docker container ls -a
```

### 5.3 Replace it

```bash
docker container rm web-2
docker container run -d --name web-2 -p 8082:80 nginx:1.25
```

30 seconds, start to finish. No debugging, no fixing — replace and move on. This is the
**cattle** model the slides described.

### 5.4 Tear the whole lot down

```bash
docker container rm -f web-1 web-2 web-3
```

---

## Part 6: Explore OCI Compliance

### 6.1 Inspect the image format

```bash
docker image pull alpine:3.19

# Save the image to a tarball
docker image save alpine:3.19 -o alpine.tar
tar -tf alpine.tar | head
tar -xOf alpine.tar manifest.json | python3 -m json.tool
```

You'll see a `manifest.json` pointing to a config blob and layer tarballs — the OCI image
format.

### 6.2 Clean up

```bash
rm alpine.tar
```

---

## Clean Up

```bash
# Remove all stopped containers + dangling images
docker system prune
```

---

## Summary

After completing this lab you should be able to:

- Install Docker and verify the client/daemon split (`docker version`, `docker info`)
- Run containers in three modes: **foreground**, **detached**, and **interactive**
- Explain why containers start in milliseconds while VMs take seconds or minutes
- Observe that a container process is just a host process in its own namespaces
- Replace a "broken" container instead of repairing it
- Inspect the OCI image format as a plain tarball of manifests + layers

---

## Stretch Goals

1. Install [Podman](https://podman.io) and run `podman run hello-world`. What changes? What
   stays the same? What does this tell you about OCI compliance?
2. Pull two different tags of the same image (`nginx:1.25`, `nginx:1.25-alpine`) and look at
   `docker image ls` sizes. Which one would you choose for a production deploy and why?
3. Run `docker stats` in one terminal and repeatedly start/stop `nginx` in another. Watch
   how resource use changes.
