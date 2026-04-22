# Session 5 — Dockerfile Best Practices & Advanced Builds

---

## Anatomy of a Dockerfile

A Dockerfile is a sequence of instructions. Each instruction produces a layer (with a few
exceptions). Instructions run top to bottom during `docker build`.

```dockerfile
# Comment
FROM python:3.11-slim                    # base image (layer)
LABEL org.opencontainers.image.source="https://github.com/me/app"
ARG APP_VERSION=dev                      # build-time variable (no layer)
ENV APP_ENV=production                   # runtime env var (no layer)
WORKDIR /app                             # sets cwd (small layer)
COPY requirements.txt .                  # copy file(s) (layer)
RUN pip install --no-cache-dir -r requirements.txt    # (layer)
COPY . .                                 # copy source (layer)
USER 1000:1000                           # drop root
EXPOSE 8080                              # metadata only
ENTRYPOINT ["python", "-m", "app"]
CMD ["--port", "8080"]
```

---

## The Instructions You'll Use Every Day

| Instruction | Makes a layer? | Purpose |
|---|---|---|
| `FROM` | Yes (the base) | Set the base image |
| `ARG` | No | Build-time variable |
| `ENV` | Small | Runtime environment variable |
| `LABEL` | Small | Image metadata (e.g., OCI annotations) |
| `WORKDIR` | Small | Set the working directory |
| `RUN` | **Yes** — usually the biggest | Execute a command during build |
| `COPY` | Yes | Copy files from context into image |
| `ADD` | Yes | Like COPY + URL fetching + tar extraction (avoid) |
| `USER` | Small | Set the default user for later instructions & runtime |
| `EXPOSE` | No | Metadata — documents a port (does not publish) |
| `VOLUME` | Small | Declare a mount point (auto-anonymous volume on run) |
| `ENTRYPOINT` | No | Fixed command; args from `run` are appended |
| `CMD` | No | Default args; can be overridden by `docker run` args |
| `HEALTHCHECK` | No | How Docker tests the container is alive |
| `STOPSIGNAL` | No | Signal sent on `docker stop` (default SIGTERM) |

---

## COPY vs ADD

Both copy files into the image. `ADD` also:

- Auto-extracts local tarballs
- Fetches remote URLs

These "features" are footguns — implicit tar extraction breaks determinism; remote URLs
smuggle in un-auditable content. **Always prefer `COPY`.** Use `RUN curl …` or a separate
build step for downloads.

```dockerfile
# Good
COPY requirements.txt .
RUN curl -fsSL https://example.com/data.tgz | tar -xz

# Avoid
ADD https://example.com/data.tgz /data/
```

---

## CMD vs ENTRYPOINT

Both say "what should this container run by default" — but they compose differently.

| | `CMD` alone | `ENTRYPOINT` alone | Both |
|---|---|---|---|
| Behaviour | Default command; fully replaced by args to `docker run` | Fixed command; args to `docker run` are appended | `ENTRYPOINT` is the binary, `CMD` is the default args |

```dockerfile
# Pattern: ENTRYPOINT is the binary, CMD is the default args
FROM alpine
ENTRYPOINT ["echo"]
CMD ["hello"]
```

```bash
docker run myimage                 # prints: hello
docker run myimage world           # prints: world   (CMD replaced)
```

**Rule of thumb:** use the **exec form** (JSON array) so signals are delivered correctly.
See the next section.

---

## Shell Form vs Exec Form

```dockerfile
# SHELL form — wrapped in /bin/sh -c
CMD python -m app
# → the actual command is: /bin/sh -c "python -m app"
# Shell is PID 1; signals go to the shell, not to python

# EXEC form — argv array, no shell
CMD ["python", "-m", "app"]
# → python is PID 1; SIGTERM reaches it directly
```

**Prefer exec form** unless you specifically need shell features (pipes, variable
expansion). Shell form breaks graceful shutdown because PID 1 is the shell, and most shells
don't forward signals to child processes.

If you need shell features and signals, use `exec` explicitly:

```dockerfile
CMD ["sh", "-c", "exec python -m app --port $PORT"]
```

---

## ARG vs ENV

| | `ARG` | `ENV` |
|---|---|---|
| When it exists | Build time only | Build AND runtime |
| Visible in running container? | No | Yes |
| Changed without rebuild? | No — baked into layers | Yes — override with `-e` |
| Example use | Image version, proxy, target platform | Log level, port, runtime config |

```dockerfile
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}
LABEL version=${APP_VERSION}
```

```bash
docker build --build-arg APP_VERSION=1.2.3 -t myapp:1.2.3 .
```

> **Secrets are not ARGs.** An `ARG` value is visible in `docker history`. Use BuildKit
> secret mounts (below) for tokens.

---

## Instruction Order and Layer Caching

Each instruction consults the build cache. If the inputs haven't changed **and** the
previous layer was a cache hit, the instruction is skipped.

**The rule:** put **slow, rarely-changing** steps first; **fast, frequently-changing** steps
last.

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# ── Rarely changes: dependency manifest ──
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Frequently changes: application code ──
COPY . .

CMD ["python", "-m", "app"]
```

If `requirements.txt` is unchanged, the `pip install` layer is cached — a 90-second step
becomes instant.

**Anti-pattern:**

```dockerfile
COPY . .
RUN pip install -r requirements.txt    # every code change invalidates the install
```

---

## Reducing Image Size

**Combine related `RUN` steps and clean up in the same layer** — deleting files in a later
layer does not reclaim space; the bytes still exist in the previous layer.

```dockerfile
# Bad — apt cache remains in a lower layer
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*

# Good — one layer, cache cleaned
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
```

**Pick a minimal base:**

- `alpine` — tiny (~5 MB), uses musl libc (some Python wheels won't install)
- `debian:bookworm-slim` — ~75 MB, glibc, safe default
- `distroless` — no shell, no package manager; smallest secure runtime
- `scratch` — empty; only useful for static binaries (Go, Rust)

**Use multi-stage builds** (next section).

---

## Multi-Stage Builds

Compile in a full image; ship in a tiny one.

### Go example

```dockerfile
# ── build stage ──
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server ./cmd/server

# ── runtime stage ──
FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

Result: ~20 MB runtime image with no shell, no libc, no compiler.

### Node.js example

```dockerfile
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

### Python example

```dockerfile
FROM python:3.11 AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime
WORKDIR /app
COPY --from=build /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY . .
USER 1000
CMD ["python", "-m", "app"]
```

---

## BuildKit — Modern Build Backend

BuildKit is the default builder in Docker 23+. It enables:

- **Parallel stage execution** — independent stages run concurrently
- **Cache mounts** — persistent caches across builds (pip, apt, Go mod cache)
- **Secret mounts** — inject a secret that never lands in a layer
- **SSH forwarding** — use the host's SSH agent to clone private repos
- **Heredocs** — multi-line RUN blocks without `&& \`

Enable (usually already on):

```bash
export DOCKER_BUILDKIT=1
# or
docker buildx build …
```

### Cache mount

```dockerfile
# syntax=docker/dockerfile:1.7

FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

Pip's HTTP cache survives between builds — dependency resolution is fast again even if the
layer cache is cold.

### Secret mount

```dockerfile
# syntax=docker/dockerfile:1.7

FROM alpine
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/my-org/private.git
```

```bash
docker build --secret id=github_token,env=GH_TOKEN -t myimage .
```

The token is available during that `RUN` but is never written to any layer.

### SSH forwarding

```dockerfile
# syntax=docker/dockerfile:1.7

FROM alpine
RUN apk add --no-cache git openssh-client
RUN --mount=type=ssh git clone git@github.com:my-org/private.git
```

```bash
docker build --ssh default -t myimage .
```

### Heredoc

```dockerfile
RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
rm -rf /var/lib/apt/lists/*
EOF
```

---

## Non-Root by Default

Containers default to `root`. Create and use an unprivileged user:

```dockerfile
FROM debian:bookworm-slim
RUN useradd --create-home --uid 1000 app
USER app
WORKDIR /home/app
```

Or the stateless form (no /etc/passwd entry needed for many tools):

```dockerfile
USER 1000:1000
```

Kubernetes reinforces this with `securityContext.runAsNonRoot: true` — Session 21.

---

## HEALTHCHECK

Docker can probe the container to determine if it's healthy.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fsS http://localhost:8080/healthz || exit 1
```

`docker ps` will show `(healthy)` / `(unhealthy)`. Compose and orchestrators can act on it.

> In Kubernetes, use `livenessProbe` / `readinessProbe` instead — the Dockerfile
> `HEALTHCHECK` is ignored.

---

## Linting with hadolint

[hadolint](https://github.com/hadolint/hadolint) checks Dockerfiles for common mistakes and
style issues.

```bash
docker run --rm -i hadolint/hadolint < Dockerfile
```

Typical findings: pinning apt packages, avoiding `latest`, missing `--no-install-recommends`,
large `ADD` usage, `RUN` without cache cleanup.

Wire it into CI so bad Dockerfiles never merge.

---

## A Checklist for Every Dockerfile

- [ ] Pin the base image (`python:3.11.7-slim`, not `python`)
- [ ] Put rarely-changing layers before frequently-changing ones
- [ ] Use `.dockerignore` to keep the build context small
- [ ] Prefer `COPY` over `ADD`
- [ ] Use the exec form for `CMD` / `ENTRYPOINT`
- [ ] Combine `RUN` steps; clean caches in the same layer
- [ ] Use multi-stage builds to strip build tools from the runtime image
- [ ] Set a non-root `USER`
- [ ] Add a `HEALTHCHECK` (or a k8s readiness probe)
- [ ] Add OCI labels for source, version, licences
- [ ] Lint with hadolint in CI

---

## Key Takeaways

- Each instruction is a layer; **order determines cache hit rate**
- `COPY` beats `ADD`; **exec form** beats shell form; `CMD` + `ENTRYPOINT` compose
- `ARG` is build-time, `ENV` is runtime; secrets go in **BuildKit secret mounts**
- Multi-stage builds shrink runtime images dramatically
- Combine `RUN`s and clean caches to avoid phantom bytes in lower layers
- Default to non-root; add healthchecks; lint in CI

---

## Review Questions

### Beginner

1. What's the difference between `CMD` and `ENTRYPOINT`, and when does each get overridden?
2. Why do we put `COPY requirements.txt` and `pip install` *before* `COPY . .`?
3. What's the difference between `ARG` and `ENV`?
4. Why is a multi-stage build smaller than a single-stage build of the same Go app?
5. What does `--no-install-recommends` do for apt packages, and why use it?

### Intermediate

1. A teammate writes `RUN rm -rf /var/cache/apt/*` after a separate `RUN apt-get install`.
   The final image isn't any smaller than before. Explain why, and show the correct pattern.
2. Your Python build step takes 90 seconds on every commit, even when `requirements.txt`
   hasn't changed. How would you diagnose the cache miss and what BuildKit feature would help
   if the issue is a cold cache on CI runners?
3. You need to `pip install` a package from a private PyPI mirror that requires a token. How
   do you get the token into the build without committing it to the image? Name two BuildKit
   options.
