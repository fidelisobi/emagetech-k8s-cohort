# Session 3 — Running Containers

---

## Your First Container

```bash
docker container run hello-world
```

What happened:

1. Client asked the daemon for the `hello-world` image
2. Daemon didn't have it locally → pulled from Docker Hub
3. Daemon created a container from the image
4. containerd/runc started the container; it printed its message and exited
5. The exited container is still on disk — `docker ps -a` will show it

**Try variations:**

```bash
docker container run busybox echo "hello"
docker container run alpine sh -c "uname -r && whoami"
docker container run -it ubuntu bash     # interactive shell
```

---

## The `docker run` Command

```
docker container run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

Most-used flags:

| Flag | Purpose |
|---|---|
| `-d` / `--detach` | Run in background; print container ID |
| `-it` | Interactive + TTY (needed for shells) |
| `--name NAME` | Give the container a stable name |
| `-p HOST:CONTAINER` | Publish a container port on the host |
| `-e KEY=VALUE` | Set an environment variable |
| `--env-file FILE` | Load env vars from a file |
| `-v HOST:CONTAINER` | Mount a host path or volume |
| `--rm` | Remove the container automatically when it exits |
| `--restart POLICY` | Restart policy (`no`, `always`, `on-failure`, `unless-stopped`) |
| `--memory` / `--cpus` | Resource limits (Session 9 goes deeper) |
| `--network NAME` | Attach to a specific network |
| `--user UID:GID` | Run as a non-root user |
| `--read-only` | Make the container filesystem read-only |

---

## Detached vs Interactive vs Foreground

```bash
# Foreground — blocks the terminal, logs stream to stdout
docker container run nginx

# Detached — returns immediately with a container ID
docker container run -d --name web nginx

# Interactive — shell into the container
docker container run -it --rm alpine sh
```

The `-i` flag keeps stdin open. The `-t` flag allocates a pseudo-TTY. You almost always
want them together for shells (`-it`).

---

## Port Publishing

By default a container is reachable only from other containers on the same network. To
expose a port on the host:

```bash
# Host port 8080 → container port 80
docker container run -d -p 8080:80 --name web nginx

# Bind to a specific interface
docker container run -d -p 127.0.0.1:8080:80 nginx

# Let Docker pick a random host port
docker container run -d -P nginx
docker container port <container>
```

- `-p` publishes **one** port, `-P` publishes **every** `EXPOSE`d port to random host ports
- This is a NAT rule on the host; the container itself does not know about the host port

---

## Environment Variables

```bash
docker container run -d \
  -e DATABASE_URL=postgres://db:5432/app \
  -e LOG_LEVEL=debug \
  myapp:1.0

# Or load from a file (format: KEY=VALUE per line)
docker container run -d --env-file .env myapp:1.0
```

> **Never bake secrets into images.** Env vars are visible via `docker inspect`, process
> listings, and kernel logs. For real secrets use Docker secrets, a secrets manager, or
> Kubernetes Secrets (Session 15).

---

## Container Lifecycle

```
                    ┌────────┐
                    │created │
                    └───┬────┘
                        │ start
                        ▼
        ┌───────┐     ┌────────┐   pause     ┌────────┐
   stop │       │     │running │ ──────────► │ paused │
   ◄────┤       ├────►│        │◄──────────  │        │
        │       │     └───┬────┘   unpause   └────────┘
        │stopped│         │
        │       │         │ process exits OR kill
        │       │         ▼
        │       │     ┌────────┐
        │       │     │ exited │
        └───────┘     └───┬────┘
                          │ rm
                          ▼
                      (removed)
```

**Commands:**

```bash
docker container create --name web nginx      # create but don't start
docker container start web                    # start a created/stopped container
docker container pause web                    # freeze all processes (SIGSTOP)
docker container unpause web                  # resume
docker container stop web                     # SIGTERM, then SIGKILL after grace
docker container kill web                     # SIGKILL immediately
docker container restart web                  # stop + start
docker container rm web                       # delete (must be stopped, or use --force)
```

---

## Linux Signals — stop, kill, SIGTERM, SIGINT

When you `docker stop`, the daemon sends **SIGTERM** to PID 1 inside the container, then
waits (default 10 seconds) before sending **SIGKILL**.

| Signal | Meaning | How to send |
|---|---|---|
| `SIGTERM` (15) | Polite: shut down cleanly | `docker container stop` |
| `SIGINT` (2) | Interrupt, like Ctrl-C | `docker container kill -s INT` |
| `SIGKILL` (9) | Immediate, non-catchable | `docker container kill` |
| `SIGHUP` (1) | Reload config | `docker container kill -s HUP` |

**Your app should handle SIGTERM** — close connections, flush buffers, exit with code 0.
Ignoring it means the daemon will `SIGKILL` you after the grace period, losing in-flight
work.

Override the grace period:

```bash
docker container stop -t 30 web   # wait 30 seconds before SIGKILL
```

---

## CMD vs ENTRYPOINT (preview)

Both control what runs when the container starts. You'll meet them properly in Session 5,
but you'll see them immediately:

```bash
# Dockerfile CMD is the default; args to `run` replace it
docker container run nginx                 # runs CMD from image (nginx -g 'daemon off;')
docker container run nginx nginx -v        # replaces CMD; prints version and exits

# With ENTRYPOINT, args to `run` are appended
docker container run curlimages/curl -sL https://example.com
```

---

## Inspecting Containers

```bash
# List running containers
docker container ls
docker container ls -a          # include stopped

# Detailed config + state — JSON
docker container inspect web

# One field via Go template
docker container inspect -f '{{.NetworkSettings.IPAddress}}' web

# Live CPU/memory/IO
docker container stats

# Processes inside the container (seen from the host)
docker container top web

# Logs
docker container logs web
docker container logs -f --tail 100 web      # follow, last 100 lines

# Shell into a running container
docker container exec -it web sh
docker container exec -it web ps aux

# Copy files in/out
docker container cp web:/etc/nginx/nginx.conf ./nginx.conf
docker container cp ./index.html web:/usr/share/nginx/html/
```

---

## Restart Policies

Docker can restart a container automatically if it exits.

| Policy | Behaviour |
|---|---|
| `no` (default) | Never restart |
| `on-failure[:N]` | Restart only on non-zero exit, up to N times |
| `always` | Always restart; also on daemon startup |
| `unless-stopped` | Same as `always`, but does not restart if you manually stopped it |

```bash
docker container run -d --restart unless-stopped --name web nginx
docker container run -d --restart on-failure:5 --name worker myjob
```

**Note:** Kubernetes has its own restart policy (`restartPolicy: Always/OnFailure/Never`)
that supersedes this — Docker restart policies matter on plain Docker hosts.

---

## Resource Limits (Introduction)

Without limits, a container can consume all host CPU and memory.

```bash
# Hard memory cap — OOM-killed if exceeded
docker container run -d --memory=512m --name app myapp

# CPU quota — 1.5 CPUs worth of time
docker container run -d --cpus=1.5 --name app myapp

# Verify
docker container stats app
```

These flags map onto **cgroups** on the host (Session 9). Kubernetes `resources.limits` uses
the same mechanism.

---

## Cleaning Up

Stopped containers, dangling images, and unused networks add up quickly.

```bash
# Remove specific container
docker container rm web
docker container rm -f web          # force — stop then remove

# Remove all stopped containers
docker container prune

# Remove everything unused (containers, networks, dangling images)
docker system prune

# Plus unused images and build cache — aggressive
docker system prune -a --volumes

# See disk usage
docker system df
docker system df -v     # verbose
```

---

## Key Takeaways

- `docker container run` = pull + create + start in one command
- `-d` detaches, `-it` gives you an interactive terminal, `--rm` cleans up on exit
- Port publishing (`-p`) is a NAT rule on the host; the container doesn't know about it
- Handle **SIGTERM** in your app — Docker's `stop` gives you 10s before SIGKILL
- Containers transition through **created → running → exited** — removed is separate
- Use `logs`, `exec`, `inspect`, `stats` to debug running containers
- Apply `--restart`, `--memory`, `--cpus` to make a container self-healing and bounded

---

## Review Questions

### Beginner

1. What is the difference between `-d`, `-it`, and `--rm`?
2. What does `-p 8080:80` do, and which port number is the host's and which is the container's?
3. What signal does `docker stop` send first, and what happens if the container ignores it?
4. How do you get a shell inside a container that is already running?
5. Why does `docker ps` not show a container that has exited, and how do you see it?

### Intermediate

1. A container you started with `--restart always` won't die — you keep stopping it and
   something keeps bringing it back after a reboot. What is happening and how do you actually
   remove it?
2. You run `docker run -p 80:80 nginx` twice. The second one fails. Why? What fails, the
   container or the port publish, and how would you diagnose it?
3. Your app leaks file descriptors and dies after a few hours. Walk through the commands
   you'd use to (a) confirm it's dying, (b) inspect why, and (c) make it auto-recover while
   you investigate.
