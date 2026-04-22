# Lab 05: Dockerfiles — Multi-Stage, BuildKit, Best Practices

## Overview

You'll write a realistic multi-stage Dockerfile for a Go and a Python app, measure the size
reduction, use BuildKit cache and secret mounts, and lint the final result with `hadolint`.

**Estimated time:** 60 minutes

**Prerequisites:**

- Docker 23+ (BuildKit is default)
- `jq`, `curl`
- Internet access

---

## Part 1: Scaffold a Sample App (Go)

Create a tiny Go HTTP server you can containerise:

```bash
mkdir -p ~/docker-lab-05/go-app && cd ~/docker-lab-05/go-app

cat > go.mod <<'EOF'
module example.com/hello

go 1.22
EOF

cat > main.go <<'EOF'
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    port := os.Getenv("PORT")
    if port == "" { port = "8080" }
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "hello from go")
    })
    fmt.Println("listening on", port)
    http.ListenAndServe(":"+port, nil)
}
EOF
```

---

## Part 2: Single-Stage — the Naive Approach

```bash
cat > Dockerfile.naive <<'EOF'
FROM golang:1.22
WORKDIR /src
COPY . .
RUN go build -o /app ./...
CMD ["/app"]
EOF

docker image build -f Dockerfile.naive -t hello:naive .
docker image ls hello:naive
```

Expect ~1 GB+. Most of it is the Go toolchain that nothing runtime needs.

---

## Part 3: Multi-Stage — the Right Way

```bash
cat > Dockerfile <<'EOF'
# ---- build stage ----
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./...

# ---- runtime stage ----
FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
EOF

docker image build -t hello:multi .
docker image ls hello
```

Expect the runtime image to be a couple of MB — no shell, no libc, no Go toolchain.

### 3.1 Confirm it still works

```bash
docker container run --rm -d -p 8080:8080 --name hello hello:multi
curl http://localhost:8080
docker container rm -f hello
```

---

## Part 4: BuildKit — Cache Mounts

### 4.1 See a cold `go mod download`

```bash
docker builder prune -af
time docker image build -t hello:multi .
```

Note how long `go mod download` takes.

### 4.2 Add a cache mount

```bash
cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1.7

FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./...

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
EOF

docker builder prune -af
time docker image build -t hello:multi .     # cold — populates the cache
time docker image build -t hello:multi .     # warm — cache mount hits
```

The cache survives across builds even when layer cache is busted.

---

## Part 5: BuildKit — Secret Mounts

Simulate using a token to download a private artifact.

### 5.1 Make a fake token

```bash
export MY_TOKEN=$(openssl rand -hex 16)
echo "token: $MY_TOKEN"
```

### 5.2 Dockerfile that uses it — without leaking it

```bash
cat > Dockerfile.secret <<'EOF'
# syntax=docker/dockerfile:1.7
FROM alpine
RUN --mount=type=secret,id=my_token \
    TOKEN=$(cat /run/secrets/my_token) && \
    echo "Token starts with ${TOKEN:0:4} (total length $(echo -n $TOKEN | wc -c))" > /where-token-was-used
EOF

docker image build --secret id=my_token,env=MY_TOKEN -f Dockerfile.secret -t hello:secret .
```

### 5.3 Confirm the token is not in the image

```bash
docker container run --rm hello:secret cat /where-token-was-used
docker image history --no-trunc hello:secret   # no token in any layer
```

The token is available during that `RUN` step only. It is never written to the filesystem,
never visible in the layer diff, never in `docker history`.

---

## Part 6: A Python App with Multi-Stage

### 6.1 Scaffold

```bash
cd ~/docker-lab-05 && mkdir py-app && cd py-app

cat > requirements.txt <<'EOF'
flask==3.0.3
gunicorn==22.0.0
EOF

cat > app.py <<'EOF'
from flask import Flask
app = Flask(__name__)
@app.get("/")
def hello(): return "hello from python\n"
EOF
```

### 6.2 Dockerfile

```bash
cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1.7

FROM python:3.11-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime
WORKDIR /app
COPY --from=build /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY app.py .
RUN useradd --create-home --uid 1000 app && chown -R app /app
USER app
EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
EOF

docker image build -t hello-py:1.0 .
docker container run --rm -d -p 8081:8080 --name hello-py hello-py:1.0
sleep 1
curl http://localhost:8081
docker container rm -f hello-py
```

---

## Part 7: CMD vs ENTRYPOINT — Hands On

### 7.1 CMD only

```bash
cat > Dockerfile.cmd <<'EOF'
FROM alpine
CMD ["echo", "hello from CMD"]
EOF
docker image build -f Dockerfile.cmd -t demo:cmd .

docker container run --rm demo:cmd                 # "hello from CMD"
docker container run --rm demo:cmd whoami          # "root" — CMD replaced entirely
```

### 7.2 ENTRYPOINT only

```bash
cat > Dockerfile.ent <<'EOF'
FROM alpine
ENTRYPOINT ["echo", "hello"]
EOF
docker image build -f Dockerfile.ent -t demo:ent .

docker container run --rm demo:ent                 # "hello"
docker container run --rm demo:ent world           # "hello world" — args appended
```

### 7.3 Both

```bash
cat > Dockerfile.both <<'EOF'
FROM alpine
ENTRYPOINT ["echo"]
CMD ["default"]
EOF
docker image build -f Dockerfile.both -t demo:both .

docker container run --rm demo:both                # "default"
docker container run --rm demo:both override       # "override"
```

> **Question:** Which pattern — CMD only, ENTRYPOINT only, or both — gives you the most
> sensible behaviour for a CLI tool? Which for a long-running server?

---

## Part 8: Shell vs Exec Form — Signal Handling

### 8.1 Shell form breaks SIGTERM

```bash
cat > Dockerfile.shell <<'EOF'
FROM alpine
CMD sleep 60
EOF
docker image build -f Dockerfile.shell -t demo:shell .

docker container run -d --name shellform demo:shell
time docker container stop shellform             # ~10 s — shell didn't forward the signal
docker container rm shellform
```

### 8.2 Exec form handles it

```bash
cat > Dockerfile.exec <<'EOF'
FROM alpine
CMD ["sleep", "60"]
EOF
docker image build -f Dockerfile.exec -t demo:exec .

docker container run -d --name execform demo:exec
time docker container stop execform              # ~instant
docker container rm execform
```

---

## Part 9: Lint with hadolint

```bash
cat > Dockerfile.bad <<'EOF'
FROM ubuntu:latest
ADD http://example.com/foo.tar.gz /
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y python
CMD ["python", "app.py"]
EOF

docker container run --rm -i hadolint/hadolint < Dockerfile.bad
```

You'll see warnings about:

- `DL3007` — don't use `latest`
- `DL3020` — use `COPY` instead of `ADD`
- `DL3008` — pin apt package versions
- `DL3009` — add `rm -rf /var/lib/apt/lists/*` after install
- `DL3015` — `--no-install-recommends`
- Separate `apt-get install` calls (bad caching)

Fix the issues and re-lint until clean.

---

## Part 10: Image Size Comparison

```bash
docker image ls --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' \
  | grep -E 'hello|demo'
```

A realistic end state:

| Image | Size |
|---|---|
| `hello:naive` | ~1000 MB |
| `hello:multi` | ~5 MB |
| `hello-py:1.0` | ~160 MB |

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker image rm $(docker image ls 'hello*' 'demo*' -q) 2>/dev/null
cd ~ && rm -rf ~/docker-lab-05
```

---

## Summary

After completing this lab you should be able to:

- Write a **multi-stage** Dockerfile for compiled and interpreted languages
- Use **BuildKit cache mounts** to skip repeated downloads across builds
- Inject **build-time secrets** safely with `--mount=type=secret`
- Predict how **CMD vs ENTRYPOINT** and **shell vs exec form** behave at `docker run` time
- Explain why shell-form CMDs break `docker stop` and how to fix them
- Lint Dockerfiles with **hadolint** and interpret the common DL-series rules

---

## Stretch Goals

1. Turn the Python app's Dockerfile into a three-stage build: `build` (compile C
   extensions), `test` (run pytest), `runtime`. Abort the build if tests fail.
2. Use `docker buildx bake` with a `docker-bake.hcl` file to build both `hello` and
   `hello-py` in one invocation.
3. Export a remote BuildKit cache to GHCR (`--cache-to type=registry`) and restore it on a
   second machine. Measure the speedup on a "cold CI runner" scenario.
