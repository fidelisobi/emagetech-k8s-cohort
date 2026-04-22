# Lab 08: Docker Compose — Multi-Container Stacks

## Overview

You'll write a realistic Compose stack (web + API + Postgres + Redis), wire services
together with DNS, persist DB state in a volume, orchestrate startup with healthchecks,
layer an override file for dev vs prod, and use profiles for optional tools.

**Estimated time:** 60 minutes

**Prerequisites:**

- Docker Compose v2 (bundled with Docker Desktop; `docker compose version`)
- `curl`, a text editor

---

## Part 1: Minimum Viable Stack

```bash
mkdir -p ~/docker-lab-08 && cd ~/docker-lab-08

cat > compose.yaml <<'EOF'
services:
  web:
    image: nginxdemos/hello:plain-text
    ports:
      - "8080:80"
EOF

docker compose up -d
curl http://localhost:8080
docker compose ps
docker compose logs web
docker compose down
```

One YAML file, two commands. This is the baseline.

---

## Part 2: Add an API and a Database

Replace `compose.yaml`:

```bash
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginxdemos/hello:plain-text
    ports:
      - "8080:80"
    depends_on:
      - api

  api:
    image: kennethreitz/httpbin
    environment:
      EXAMPLE: from-compose
    expose:
      - "80"
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
EOF
```

### 2.1 Start it

```bash
docker compose up -d
docker compose ps
```

Wait until `db` is `healthy`, then:

```bash
# From the API container, reach the db by service name
docker compose exec api sh -c "getent hosts db" 2>/dev/null || \
  docker compose exec -T api python -c "import socket; print(socket.gethostbyname('db'))"
```

### 2.2 Prove DNS and network isolation

```bash
# api can reach db
docker compose exec api curl -s -o /dev/null -w "%{http_code}\n" http://web/

# Different project → different network → can't see ours
docker run --rm --network container:$(docker compose ps -q api) alpine \
  sh -c 'apk add --quiet bind-tools 2>/dev/null; getent hosts web'
```

### 2.3 Persist across restarts

```bash
docker compose exec db psql -U app -d app -c \
  "CREATE TABLE t (id int); INSERT INTO t VALUES (1),(2),(3);"

docker compose down          # stops + removes containers, keeps named volume
docker volume ls | grep pg-data

docker compose up -d
docker compose exec db psql -U app -d app -c "SELECT count(*) FROM t;"
```

---

## Part 3: Healthchecks & Ordered Startup

Add a healthcheck to `api`:

```bash
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginxdemos/hello:plain-text
    ports: ["8080:80"]
    depends_on:
      api:
        condition: service_healthy

  api:
    image: kennethreitz/httpbin
    expose: ["80"]
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost/status/200 >/dev/null || exit 1"]
      interval: 5s
      retries: 5

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
EOF

docker compose up -d
docker compose ps
```

`web` won't come up until `api` is healthy; `api` won't until `db` is ready.

> **Question:** What's the difference between `depends_on: [db]` and
> `depends_on: { db: { condition: service_healthy } }`?

---

## Part 4: Build from a Dockerfile

Add your own tiny API service.

```bash
mkdir api
cat > api/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.3
COPY app.py .
EXPOSE 8080
CMD ["python", "-u", "app.py"]
EOF

cat > api/app.py <<'EOF'
import os
from flask import Flask, jsonify
app = Flask(__name__)

@app.get("/")
def hello():
    return jsonify(greeting=os.environ.get("GREETING", "hi"),
                   target=os.environ.get("TARGET", "world"))

@app.get("/health")
def health():
    return "ok\n", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF
```

Wire it into the Compose file:

```bash
cat > compose.yaml <<'EOF'
services:
  api:
    build: ./api
    image: lab08-api:local
    environment:
      GREETING: hello
      TARGET: compose
    ports: ["8080:8080"]
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health | grep -q ok"]
      interval: 5s
      retries: 5
EOF

docker compose up --build -d
curl http://localhost:8080
curl http://localhost:8080/health
```

### 4.1 Iterate

```bash
# Edit api/app.py, then rebuild + roll:
docker compose up --build -d
```

---

## Part 5: Environment Files & Interpolation

### 5.1 Create a `.env`

```bash
cat > .env <<'EOF'
TAG=local
GREETING=hola
TARGET=engineers
EOF
```

### 5.2 Reference variables in Compose

```bash
cat > compose.yaml <<'EOF'
services:
  api:
    build: ./api
    image: lab08-api:${TAG}
    environment:
      GREETING: ${GREETING:-hi}
      TARGET: ${TARGET:-world}
    ports: ["8080:8080"]
EOF

docker compose up --build -d
curl http://localhost:8080
```

### 5.3 Render the effective config

```bash
docker compose config
```

`config` resolves all interpolation and inheritance so you can see exactly what's running.

---

## Part 6: Override Files

Keep a shared base + per-environment overrides.

```bash
cat > compose.yaml <<'EOF'
services:
  api:
    build: ./api
    image: lab08-api:${TAG:-local}
    environment:
      GREETING: hi
      TARGET: world
    ports: ["8080:8080"]
EOF

# Automatic override: compose.override.yaml is loaded by default
cat > compose.override.yaml <<'EOF'
services:
  api:
    environment:
      GREETING: hi-DEV
      LOG_LEVEL: debug
    volumes:
      - ./api:/app             # bind-mount source for hot reload
EOF

# A prod-style file you load explicitly
cat > compose.prod.yaml <<'EOF'
services:
  api:
    image: lab08-api:prod
    environment:
      GREETING: hi-PROD
      LOG_LEVEL: info
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: "256M"
EOF

# Dev — automatic override is merged in
docker compose config | grep -E 'GREETING|LOG_LEVEL|image' | head

# Prod — ignore the auto override, apply prod
docker compose -f compose.yaml -f compose.prod.yaml config | grep -E 'GREETING|LOG_LEVEL|image' | head
```

`compose.override.yaml` is loaded automatically. Explicit `-f` bypasses auto-loading.

---

## Part 7: Profiles — Optional Services

Add an admin tool that only starts when asked.

```bash
cat >> compose.yaml <<'EOF'

  adminer:
    image: adminer
    ports: ["8081:8080"]
    profiles: [tools]
EOF

docker compose up -d                                # adminer NOT started
docker compose ps
docker compose --profile tools up -d                # now adminer too
docker compose ps
docker compose --profile tools down
```

Use profiles for seeders, debuggers, schema migrators — things you don't want in the
default stack.

---

## Part 8: Networking Layouts

Multi-network "DMZ" pattern.

```bash
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginxdemos/hello:plain-text
    ports: ["8080:80"]
    networks: [edge, internal]

  api:
    image: kennethreitz/httpbin
    expose: ["80"]
    networks: [internal]

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
    networks: [internal]

networks:
  edge:
  internal:
    internal: true     # no external routing — DB has no internet egress
EOF

docker compose up -d
docker compose exec db ping -c 2 -W 2 8.8.8.8 || echo "db has no egress — good"
docker compose exec web curl -s -o /dev/null -w "%{http_code}\n" http://api/get || true
docker compose down
```

---

## Part 9: The Compose Cheat Sheet

```bash
docker compose up -d                   # start/create
docker compose up --build              # rebuild first
docker compose down                    # stop + remove containers + default network
docker compose down -v                 # ALSO remove volumes
docker compose ps                      # status
docker compose logs -f api             # follow one service
docker compose exec api sh             # shell
docker compose run --rm api pytest     # one-off, fresh container
docker compose restart api
docker compose pull                    # pre-pull images
docker compose config                  # effective merged YAML
docker compose top                     # process list per service
docker compose cp api:/app/log ./log   # copy files out
```

---

## Clean Up

```bash
docker compose down -v
cd ~ && rm -rf ~/docker-lab-08
docker image rm lab08-api:local lab08-api:prod 2>/dev/null
```

---

## Summary

After completing this lab you should be able to:

- Write a `compose.yaml` that defines services, networks, volumes, and environment
- Use `depends_on: { condition: service_healthy }` + per-service `healthcheck` for ordering
- Build images from Dockerfiles inside Compose (`build: ./dir`)
- Use `.env` + `${VAR:-default}` interpolation and verify with `docker compose config`
- Layer **override files** for dev vs prod without duplicating YAML
- Use **profiles** for optional stack components
- Create multi-network layouts with `internal: true` for egress-free backends

---

## Stretch Goals

1. Add a **migrations** service using `profiles: [migrate]` that runs `alembic upgrade head`
   against the DB and exits 0. Ensure it blocks the main `api` from starting until it's done.
2. Move secrets out of YAML — set `POSTGRES_PASSWORD_FILE` to a Docker secret
   (`secrets:` block) instead of `POSTGRES_PASSWORD`. Does it still work? What changed?
3. Map this Compose file 1:1 onto Kubernetes: which YAML becomes a Deployment, which a
   Service, which a PVC/StorageClass, which an Ingress? Sketch the manifests (you don't
   have to deploy them yet — Session 11+ covers that).
