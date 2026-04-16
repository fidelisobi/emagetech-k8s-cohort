# Docker Advanced: Networking, Volumes, Compose, Internals & Security

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Why This Matters

Once you can build and run containers, the next challenge is making them work together reliably and securely. Multi-container applications need networking (how do services find each other?), persistent storage (where does data live when a container dies?), and orchestration (how do you start a 5-service stack with one command?). Docker's solutions to these problems — bridges, volumes, and Compose — are direct conceptual predecessors to Kubernetes Services, PersistentVolumes, and Deployments.

Beyond the tooling, understanding what's actually happening under the hood — Linux namespaces, cgroups, capabilities — is what separates someone who can run containers from someone who can debug, secure, and operate them at scale. Sessions 6–10 complete your Docker foundation and prepare you to understand why Kubernetes is designed the way it is.

---

## 🎥 YouTube Videos

### Docker Networking Explained
[![Thumbnail](https://img.youtube.com/vi/bKFMS5C4CG0/0.jpg)](https://www.youtube.com/watch?v=bKFMS5C4CG0)
**Channel:** TechWorld with Nana
> Covers bridge, host, and overlay networks, port publishing, and container-to-container communication with DNS resolution.

### Docker Volumes Explained
[![Thumbnail](https://img.youtube.com/vi/p2PH_YPCsis/0.jpg)](https://www.youtube.com/watch?v=p2PH_YPCsis)
**Channel:** TechWorld with Nana
> Complete guide to named volumes, bind mounts, and tmpfs — when to use each and how data persists across container restarts.

### Docker Compose Tutorial
[![Thumbnail](https://img.youtube.com/vi/HG6yIjZapSA/0.jpg)](https://www.youtube.com/watch?v=HG6yIjZapSA)
**Channel:** TechWorld with Nana
> Step-by-step Docker Compose tutorial — defining multi-service applications, environment variables, health checks, and service dependencies.

### Container Security Best Practices
[![Thumbnail](https://img.youtube.com/vi/JE2PJbbpjsM/0.jpg)](https://www.youtube.com/watch?v=JE2PJbbpjsM)
**Channel:** KodeKloud
> Practical container security — non-root users, read-only filesystems, image scanning, and avoiding common misconfigurations.

### Linux Namespaces and Cgroups Explained
[![Thumbnail](https://img.youtube.com/vi/_j8MZpEHfMI/0.jpg)](https://www.youtube.com/watch?v=_j8MZpEHfMI)
**Channel:** LiveOverflow
> Deep technical dive into the Linux primitives that make containers possible — namespaces for isolation, cgroups for resource limits.

---

## 📚 Articles & Documentation

### Docker Networking Overview
🔗 [Docker Networking](https://docs.docker.com/network/)
**Source:** Docker Official Docs | **Level:** Intermediate
> Complete reference for Docker network drivers, bridge networks, user-defined networks, and container DNS.

### Docker Volumes Documentation
🔗 [Docker Storage](https://docs.docker.com/storage/)
**Source:** Docker Official Docs | **Level:** Intermediate
> Official docs on volumes, bind mounts, and tmpfs — includes drivers, backup strategies, and volume lifecycle.

### Docker Compose Reference
🔗 [Docker Compose](https://docs.docker.com/compose/)
**Source:** Docker Official Docs | **Level:** Intermediate
> Complete Compose file reference, CLI commands, and best practices for multi-service applications.

### Container Security Best Practices (OWASP)
🔗 [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
**Source:** OWASP | **Level:** Intermediate
> Comprehensive container security guidance from the OWASP project — covers all the major attack surfaces.

### CIS Docker Benchmark
🔗 [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
**Source:** CIS | **Level:** Advanced
> The industry-standard security configuration benchmark for Docker — used by security teams and audit tools like Docker Bench.

---

## Key Concepts

### Docker Networking

By default, Docker creates a `bridge` network. All containers on the same bridge can communicate with each other, but are isolated from other networks.

**Network drivers**:

| Driver | Use Case |
|--------|----------|
| `bridge` | Default. Isolated network on a single host |
| `host` | Container shares host's network stack (no isolation) |
| `none` | No networking. Completely isolated |
| `overlay` | Multi-host networking (Docker Swarm / advanced) |
| `macvlan` | Container gets its own MAC address — appears as physical device |

**Default bridge vs user-defined bridge**:
- Default bridge: containers can only communicate by IP address
- **User-defined bridge**: containers can communicate by **container name** (DNS resolution is automatic)

```bash
# Create a user-defined network
docker network create my-network

# Both containers join the same network and can reach each other by name
docker run -d --name db --network my-network postgres:16
docker run -d --name app --network my-network -e DB_HOST=db myapp
```

**Port publishing**: `-p host_port:container_port`
```bash
docker run -p 8080:80 nginx    # host:8080 → container:80
docker run -p 127.0.0.1:5432:5432 postgres  # bind to localhost only (safer)
```

### Docker Volumes

Container filesystems are **ephemeral** — everything written inside a container is lost when the container is removed. For databases, uploads, logs, or any state that needs to survive, you need a volume.

**Three options**:

1. **Named volumes** — managed by Docker, stored in `/var/lib/docker/volumes/`
   ```bash
   docker volume create pgdata
   docker run -v pgdata:/var/lib/postgresql/data postgres:16
   ```

2. **Bind mounts** — mount a host directory into the container
   ```bash
   docker run -v /host/path:/container/path myapp
   # Or with --mount (more explicit):
   docker run --mount type=bind,src=/host/path,dst=/container/path myapp
   ```

3. **tmpfs mounts** — in-memory only, never written to disk (great for secrets or scratch space)
   ```bash
   docker run --tmpfs /tmp myapp
   ```

**Volume lifecycle**: volumes persist even after the container is removed. Clean up with `docker volume prune`.

**Backup pattern**: `docker run --rm -v pgdata:/data -v $(pwd):/backup alpine tar czf /backup/pgdata.tar.gz -C /data .`

### Docker Compose

Compose lets you define and run multi-service applications from a single `docker-compose.yml` file.

```yaml
version: "3.9"
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}    # from .env file
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://postgres:${DB_PASSWORD}@db:5432/mydb
    depends_on:
      db:
        condition: service_healthy   # wait for health check to pass

volumes:
  pgdata:
```

**Key commands**:
```bash
docker compose up -d          # start all services in background
docker compose down           # stop and remove containers
docker compose down -v        # also remove volumes
docker compose logs -f app    # stream logs for one service
docker compose ps             # list service status
docker compose exec app bash  # shell into a running service
docker compose build          # rebuild images
```

**Bridge to Kubernetes**: Compose is excellent for local development, but Kubernetes replaces it in production. The mental model maps directly: services → Deployments, volumes → PersistentVolumes, networks → Services, depends_on → init containers or readiness probes.

### Container Internals: Linux Namespaces and cgroups

Containers are **not magic** — they're Linux processes with two key primitives applied:

**Namespaces** provide isolation — each namespace type hides a different view of the system:

| Namespace | Isolates |
|-----------|---------|
| `pid` | Process IDs — container has its own PID 1 |
| `net` | Network interfaces, routing, ports |
| `mnt` | Mount points and filesystems |
| `uts` | Hostname and domain name |
| `ipc` | Inter-process communication (shared memory, semaphores) |
| `user` | User and group IDs (user namespaces enable rootless containers) |

**cgroups** (control groups) enforce resource limits — CPU, memory, I/O:
```bash
# See cgroup limits for a container
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes
```

- **cgroups v1**: Per-subsystem hierarchy, widely supported
- **cgroups v2**: Unified hierarchy, better resource accounting, required for some Kubernetes features (like proper memory.oom.group behavior)

**Linux capabilities**: Rather than full root, containers can be granted specific capabilities (e.g., `NET_BIND_SERVICE` to bind to ports < 1024). Best practice: drop all capabilities, add only what's needed.

**seccomp, AppArmor, SELinux**: Mandatory access control mechanisms that restrict what syscalls a container can make and what files it can access. Docker's default seccomp profile blocks ~40 dangerous syscalls.

**The key insight**: A container is just a process. Run `ps aux` on a Docker host and you'll see container processes right there alongside host processes. The isolation is real but it's enforced by the kernel, not by a separate VM boundary.

### Container Security

**Attack surface areas**:
1. The image itself (vulnerable packages, leaked secrets, malicious base images)
2. The container runtime configuration (privileged mode, excessive capabilities)
3. The host kernel (shared kernel means a container escape = host compromise)
4. The registry and supply chain (tampered images, unverified provenance)

**Image scanning**:
- **Trivy** (Aqua): Fast, easy to use. `trivy image nginx:1.25`
- **Grype** (Anchore): Good for CVE matching, integrates with SBOMs
- **Snyk**: Commercial with free tier, integrates with CI/CD

**Supply chain security**:
- **cosign** (Sigstore): Sign and verify container images with keyless signing
- **SBOMs** (Software Bill of Materials): A manifest of all components in your image (Syft generates these)
- **SLSA**: Framework for supply chain integrity levels

**Runtime hardening**:
```dockerfile
# Run as non-root
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Read-only root filesystem (override in docker run with --read-only)
```

```bash
# Never run this in production!
docker run --privileged myapp  # full host access

# Drop capabilities
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE myapp

# Read-only filesystem
docker run --read-only --tmpfs /tmp myapp
```

**Secrets management**: Never bake secrets into images. Use:
- Docker BuildKit secrets (`--secret` flag, not stored in layers)
- Environment variables injected at runtime (not ideal for highly sensitive data)
- External secret managers (Vault, AWS Secrets Manager, Kubernetes Secrets)

**CIS Docker Benchmark**: Run `docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /usr/local/bin/docker:/usr/local/bin/docker docker/docker-bench-security` to audit your Docker installation against the CIS benchmark.

---

## Key Concepts to Know Before Class

- What are the four Docker network drivers? When would you use each?
- Why does container-to-container DNS work on user-defined bridges but not the default bridge?
- What is the difference between a named volume and a bind mount? When would you choose each?
- What happens to data written inside a container when the container is removed?
- How do you define service dependencies with health checks in Docker Compose?
- What are Linux namespaces? Name all six types and what each isolates.
- What are cgroups? What is the difference between v1 and v2?
- Why do we say "containers are just processes"?
- What is the default Docker seccomp profile and why does it matter?
- Name three image scanning tools and explain what they scan for.
- What is cosign/Sigstore and what problem does it solve?
- What is an SBOM and why is it important for supply chain security?
- Why should containers run as non-root? How do you enforce this?
- What does `--cap-drop ALL` do? What capabilities are commonly needed?
- What is the CIS Docker Benchmark?

---

## Hands-On Before Class (Optional)

1. **Explore Docker networks**: Create two containers on the default bridge and one on a user-defined bridge. Try to ping by name. See what works.
2. **Named volume persistence**: Run a postgres container with a named volume, write some data, stop and remove the container, start a new one with the same volume, verify the data is still there.
3. **Docker Compose app**: Write a docker-compose.yml for a web app + database (e.g., Flask + PostgreSQL or Node + MongoDB). Include health checks and `depends_on`.
4. **Inspect namespaces**: On a Linux host (or Docker Desktop VM), run `lsns` while a container is running. Find the container's namespaces.
5. **Scan an image**: Run `trivy image python:3.11` and `trivy image python:3.11-slim`. Compare the vulnerability counts.
6. **Security hardening**: Take a Dockerfile and add a non-root user, drop capabilities in your docker-compose.yml, and add a read-only filesystem. Verify the app still works.
7. **Understand BuildKit secrets**: Write a Dockerfile that uses `--mount=type=secret` to access a secret at build time without it appearing in any layer.
