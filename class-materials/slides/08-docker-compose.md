# Session 8 — Docker Compose & Multi-Container Apps

---

## Why Compose?

Running one container is easy. Running a realistic app — web + API + database + cache +
message queue — means:

- Five or six `docker run` commands with different flags
- A user-defined network to wire them together
- Volumes, environment variables, restart policies, healthchecks
- The right startup order

**Docker Compose** describes all of that **declaratively** in a single YAML file and brings
the stack up with one command.

```bash
docker compose up -d
```

---

## Compose v1 vs v2

- **v1** — separate `docker-compose` Python binary. End-of-life; avoid.
- **v2** — a plugin to Docker CLI. You invoke it as `docker compose` (no hyphen).

Everything below assumes v2. `compose.yaml` and `docker-compose.yaml` are both valid filenames.

---

## A Minimal `compose.yaml`

```yaml
services:
  web:
    image: nginx:1.25
    ports:
      - "8080:80"
    depends_on:
      - api

  api:
    build: ./api
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/app
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app
    volumes:
      - pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  pg-data:
```

`docker compose up -d` and you have a three-service stack with a private network, a named
volume, a healthcheck, and proper startup ordering.

---

## File Anatomy

Top-level keys:

| Key | Purpose |
|---|---|
| `services` | The containers |
| `networks` | Networks to create (one default network is implicit) |
| `volumes` | Named volumes |
| `configs` / `secrets` | File-based config/secrets (Swarm; usable in Compose) |
| `name` | Override the project name (default: directory name) |

Each service can set:

- `image` — use a prebuilt image
- `build` — build from a Dockerfile in this repo
- `command` / `entrypoint` — override CMD / ENTRYPOINT
- `environment`, `env_file` — env vars
- `ports`, `expose` — port publishing (to host vs just between services)
- `volumes`, `tmpfs` — storage
- `depends_on` — startup ordering
- `healthcheck` — per-service probe
- `restart` — `no | always | on-failure | unless-stopped`
- `deploy.resources` — CPU / memory limits
- `networks` — attach to specific networks
- `profiles` — opt-in/out groups of services

---

## Projects, Networks, Names

Compose isolates stacks by **project name** (default: the directory name). It prefixes
all resources:

```
<project>_<service>_<index>   # container names
<project>_default             # network
<project>_pg-data             # volumes
```

This means running the same Compose file in `./app1/` and `./app2/` gives you two
independent, non-conflicting stacks.

```bash
docker compose ps
docker compose -p myapp up -d
docker compose --project-name staging up -d
```

---

## Service Discovery Inside Compose

All services on a Compose project share a **user-defined bridge** network. Each service is
reachable by its **service name** from the others.

```yaml
services:
  api:
    image: myapi
    environment:
      REDIS_URL: redis://cache:6379       # ← 'cache' resolves to the redis container
  cache:
    image: redis:7
```

No IPs, no ports on the host unless you explicitly publish. This is the Compose equivalent
of Kubernetes Service-by-name DNS.

---

## Dependencies and Healthchecks

`depends_on` alone only controls **start order** — it does not wait for the dependency to
be ready. Use `condition: service_healthy` with a healthcheck for that.

```yaml
services:
  api:
    build: ./api
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s
```

Without the healthcheck, `api` will try to connect before Postgres is accepting connections.

---

## Environment Variables and Interpolation

Compose interpolates `${VAR}` from:

1. A `.env` file in the working directory
2. The host shell environment

```yaml
services:
  api:
    image: myapi:${TAG:-latest}
    environment:
      DATABASE_URL: ${DATABASE_URL}
      LOG_LEVEL: ${LOG_LEVEL:-info}
```

`.env`:

```
TAG=1.4.2
DATABASE_URL=postgres://app:secret@db:5432/app
```

`${VAR:-default}` supplies a fallback if the variable isn't set. Missing required variables
fail the `up`.

**Per-service env file:**

```yaml
services:
  api:
    image: myapi
    env_file:
      - ./config/api.env
```

---

## Building vs Pulling

A service can specify either `image:` (pull) or `build:` (build from Dockerfile), or both:

```yaml
services:
  api:
    image: ghcr.io/me/api:dev          # tag after build
    build:
      context: ./api
      dockerfile: Dockerfile
      args:
        APP_VERSION: 1.4.2
      target: runtime
```

- `docker compose build` builds every service with a `build:` key
- `docker compose up --build` forces a rebuild on startup
- `docker compose push` pushes built images that also have `image:`

---

## Ports: `ports` vs `expose`

- `ports` — publishes to the host (appears to the outside world)
- `expose` — documents that the service listens on that port; reachable only by other
  containers on the same network. Not strictly required (containers can connect on any port
  anyway) but helps readability and Swarm scheduling.

```yaml
services:
  web:
    image: nginx
    ports:
      - "8080:80"         # host 8080 → container 80
      - "127.0.0.1:9443:443"

  internal:
    image: myworker
    expose:
      - "9000"            # other services can reach internal:9000; host cannot
```

---

## Volumes in Compose

Named volumes declared at the top level; bind mounts inline.

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - pg-data:/var/lib/postgresql/data   # named
      - ./init-sql:/docker-entrypoint-initdb.d:ro    # bind, read-only

volumes:
  pg-data:
    # optional driver config
    driver: local
```

---

## Networks in Compose

By default, all services join a single project network. Override to get multi-network
layouts (e.g., a DMZ vs internal network):

```yaml
services:
  web:
    image: nginx
    networks: [edge, internal]
  api:
    image: myapi
    networks: [internal]
  db:
    image: postgres:16
    networks: [internal]

networks:
  edge:
  internal:
    internal: true     # no egress to the outside
```

---

## Profiles — Optional Services

Use `profiles` to define services that only come up when asked. Good for dev-only tools
(debugger, seeder, admin UI) you don't want in the default stack.

```yaml
services:
  db:
    image: postgres:16
  adminer:
    image: adminer
    ports: ["8081:8080"]
    profiles: [tools]
```

```bash
docker compose up -d                 # just db
docker compose --profile tools up -d # db + adminer
```

---

## Everyday Commands

```bash
docker compose up -d                        # bring the stack up in background
docker compose up --build                   # rebuild before up
docker compose down                         # stop and remove containers + default network
docker compose down -v                      # ALSO remove named volumes
docker compose ps                           # show stack status
docker compose logs -f api                  # follow one service's logs
docker compose exec api sh                  # shell into a running service
docker compose run --rm api pytest          # one-off command; fresh container
docker compose restart api                  # restart just one service
docker compose config                       # resolve & print the effective config
docker compose pull                         # pre-pull all images
docker compose top                          # per-service process list
```

- `up` is additive — it starts what isn't already running, recreates services with changed config
- `down` is destructive for the stack (but preserves named volumes unless `-v`)

---

## Overrides and Multiple Files

Compose reads `compose.yaml` **plus** `compose.override.yaml` automatically. Layer
environment-specific files explicitly with `-f`:

```
compose.yaml           # shared definition
compose.dev.yaml       # dev overrides (bind-mount source, enable debug)
compose.prod.yaml      # prod overrides (image tags, resource limits)
```

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Later files override earlier ones. Lists merge; scalars replace.

---

## Compose vs Kubernetes

Compose concepts map almost 1:1 onto Kubernetes primitives:

| Compose | Kubernetes |
|---|---|
| `service` | Deployment + Service |
| `volumes` (named) | PersistentVolumeClaim + StorageClass |
| Built-in network | ClusterIP Services + DNS |
| `depends_on` | Init containers, readiness probes |
| `environment` | env / envFrom (ConfigMap / Secret) |
| `ports` | Service (ClusterIP / NodePort / LoadBalancer) + Ingress |
| `restart: always` | Pod `restartPolicy` + controller |
| `healthcheck` | readinessProbe / livenessProbe |
| `deploy.resources` | `resources.requests` / `limits` |

**Compose is great for:**

- Local development
- Small single-host deployments
- CI test environments
- Quick reproductions for bug reports

**Compose is not:**

- Multi-host scheduling (use Swarm or Kubernetes)
- Production orchestration at scale
- A service mesh, autoscaler, or rollout manager

Tools like **Kompose** can scaffold K8s manifests from a Compose file to ease migration.

---

## A Realistic Dev Stack

```yaml
services:
  web:
    build: ./web
    command: npm run dev
    ports: ["3000:3000"]
    volumes:
      - ./web:/app
      - /app/node_modules          # anonymous volume protects node_modules
    depends_on: [api]

  api:
    build: ./api
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/app
      REDIS_URL: redis://cache:6379
      LOG_LEVEL: debug
    ports: ["4000:4000"]
    volumes:
      - ./api:/app
    depends_on:
      db:  { condition: service_healthy }
      cache: { condition: service_started }

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app
    volumes:
      - pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 10

  cache:
    image: redis:7-alpine

volumes:
  pg-data:
```

`docker compose up` → full-stack dev environment. Hot reload works via bind mounts.
Shared network, DNS by service name, single volume per stateful service.

---

## Key Takeaways

- Compose = declarative multi-container stacks in YAML, one `up` command
- Services talk by **service name** over an auto-created network
- **`depends_on` + healthcheck** are required to actually wait for dependencies
- **Named volumes** persist data; bind mounts power the dev loop
- **Profiles** isolate optional services (tools, debuggers)
- Compose concepts translate cleanly into Kubernetes — your mental model carries over

---

## Review Questions

### Beginner

1. How do two services in the same Compose file find each other?
2. What's the difference between `ports` and `expose`?
3. What does `docker compose down -v` do that `docker compose down` doesn't?
4. Why do you need a healthcheck in addition to `depends_on`?
5. What is a Compose "profile" good for?

### Intermediate

1. Your Compose stack starts `api` before `db` is ready even though you wrote
   `depends_on: [db]`. Explain why, and show the fix.
2. You want two developers on the same host to run the same Compose file for two different
   branches without clashing. What mechanism handles that, and what would go wrong if you
   hard-coded container names?
3. Map this stack (web + api + db + cache + worker) to Kubernetes: which Compose key becomes
   which K8s object, and what concerns does Compose quietly hide that K8s forces you to name?
